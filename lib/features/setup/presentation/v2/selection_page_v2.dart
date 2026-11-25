import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/theme_provider.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/auth/data/services/auth_service.dart';
import 'package:nguyenanh/features/auth/data/services/auth_storage_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Redesigned (v2) login screen. State and logic are identical to [SelectionPage]
/// (lib/features/setup/presentation/selection_page.dart); only the widget tree differs.
class SelectionPageV2 extends StatefulWidget {
  const SelectionPageV2({super.key});

  @override
  State<SelectionPageV2> createState() => _SelectionPageV2State();
}

class _SelectionPageV2State extends State<SelectionPageV2> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthStorageService _authStorage = AuthStorageService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // UI only: lets the keyboard's "next" key jump from username to password.
  final FocusNode _passwordFocus = FocusNode();

  /// Max width of the form column (scaled like every other size, so proportions match the phone design).
  double get _maxContentWidth => 460.w;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final remembered = await _authStorage.getRememberedLogin();

    if (!mounted) return;

    if (remembered['rememberMe'] == true) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = remembered['username'] ?? '';
        _passwordController.text = remembered['password'] ?? '';
      });
    }
  }

  Future<void> _savePreferences() async {
    await _authStorage.saveRememberedLogin(
      rememberMe: _rememberMe,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  Future<void> _onConfirm() async {
    final l10n = AppLocalizations.of(context)!;

    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_infoSnackBar(l10n.pleaseEnterDetails));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(ApiClient.dio);

      final result = await authService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _authStorage.saveSession(
        accessToken: result.accessToken,
        userId: result.userId,
        fullName: result.fullName,
        role: result.role,
      );

      await _savePreferences();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on DioException catch (e) {
      String message = l10n.loginGenericError;

      if (e.response?.statusCode == 401) {
        message = l10n.loginInvalidCredentials;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        message = l10n.loginServerUnavailable;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(_errorSnackBar(message));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(_errorSnackBar(l10n.loginGenericError));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPartnershipSite() async {
    final uri = Uri.parse('https://nguyenanhgroup.vn/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLanguagePicker() {
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
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.translate_rounded,
                  title: l10n.selectLanguage,
                ),
                _LanguageOption(
                  flag: '🇻🇳',
                  label: l10n.vietnamese,
                  selected: languageProvider.locale.languageCode == 'vi',
                  onTap: () {
                    languageProvider.setLocale(const Locale('vi'));
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: 8.h),
                _LanguageOption(
                  flag: '🇺🇸',
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─── Presentation helpers ─────────────────────────────────────────────────

  /// Copy that has no AppLocalizations key yet (new in the v2 design).
  String _tr(String vi, String en) => Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

  SnackBar _infoSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18.sp, color: FxTokens.amber),
          SizedBox(width: 10.w),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  SnackBar _errorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18.sp, color: Colors.white),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: FxTokens.red,
    );
  }

  LinearGradient _brandGradient(FxTokens t) {
    // Horizontal so the fixed top bar and the scrolling hero join without a seam.
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: t.dark
          ? [Color.lerp(FxTokens.blue, t.bg, 0.45)!, Color.lerp(FxTokens.indigo, t.bg, 0.45)!]
          : const [FxTokens.blue, FxTokens.indigo],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final overlap = 52.h;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.bg,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildTopBar(t, l10n),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      children: [
                        _buildHero(t, overlap),
                        Transform.translate(
                          offset: Offset(0, -overlap),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: _maxContentWidth),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildLoginCard(t, l10n),
                                    SizedBox(height: 14.h),
                                    _buildHelpCard(t, l10n),
                                    SizedBox(height: 22.h),
                                    Center(
                                      child: Text(
                                        'v2.0.0 • NGUYÊN ANH',
                                        style: t.overline.copyWith(letterSpacing: 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fixed bar under the status bar: language switch + theme switch.
  Widget _buildTopBar(FxTokens t, AppLocalizations l10n) {
    final code = Localizations.localeOf(context).languageCode.toUpperCase();
    return Container(
      decoration: BoxDecoration(gradient: _brandGradient(t)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
          child: Row(
            children: [
              Tooltip(
                message: l10n.selectLanguage,
                child: _GlassButton(
                  onTap: _showLanguagePicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language_rounded, size: 16.sp, color: Colors.white),
                      SizedBox(width: 6.w),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const _GlassThemeSwitch(),
            ],
          ),
        ),
      ),
    );
  }

  /// Gradient header with the logo and the welcome copy; the form card overlaps its bottom edge.
  Widget _buildHero(FxTokens t, double overlap) {
    final cs = Theme.of(context).colorScheme;
    final logoWidth = 148.w;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _brandGradient(t),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70.w,
            bottom: -60.w,
            child: _DecorCircle(size: 220.w, alpha: 0.08),
          ),
          Positioned(
            left: -46.w,
            bottom: overlap - 10.h,
            child: _DecorCircle(size: 120.w, alpha: 0.06),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, overlap + 28.h),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  children: [
                    // Logo on a white plate (the mark is red on transparent).
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: logoWidth,
                        // logo.png is square with the artwork in its middle third → crop to it.
                        height: logoWidth / 2.8,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.local_shipping_rounded,
                            size: 36.sp,
                            color: FxTokens.blue,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 22.h),
                    Text(
                      _tr('Chào mừng trở lại', 'Welcome back'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _tr('Đăng nhập để tiếp tục quản lý đội xe của bạn', 'Sign in to continue managing your fleet'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(FxTokens t, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;

    return FxCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.login_rounded,
            title: l10n.fleetSelection,
            subtitle: _tr('Dùng tài khoản do quản trị viên cấp', 'Use the account provided by your administrator'),
          ),
          Divider(height: 1, color: t.divider),
          SizedBox(height: 16.h),
          _buildField(
            t: t,
            label: l10n.username,
            hint: _tr('Nhập tên đăng nhập', 'Enter your username'),
            controller: _usernameController,
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          SizedBox(height: 14.h),
          _buildField(
            t: t,
            label: l10n.password,
            hint: _tr('Nhập mật khẩu', 'Enter your password'),
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            focusNode: _passwordFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) _onConfirm();
            },
          ),
          SizedBox(height: 10.h),

          // REMEMBER ME
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(10.r),
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 2.w),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: _rememberMe ? cs.primary : t.cardAlt,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: _rememberMe ? cs.primary : t.border,
                          width: 1.6,
                        ),
                      ),
                      child: _rememberMe ? Icon(Icons.check_rounded, color: cs.onPrimary, size: 14.sp) : null,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        l10n.rememberMe,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // CONFIRM BUTTON
          FilledButton(
            onPressed: _isLoading ? null : _onConfirm,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, math.max(48.0, 52.h)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
              disabledForegroundColor: cs.onPrimary,
              textStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 15.sp, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading
                  ? Row(
                      key: const ValueKey('loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.onPrimary),
                        ),
                        SizedBox(width: 10.w),
                        Flexible(
                          child: Text(
                            _tr('Đang đăng nhập…', 'Signing in…'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('idle'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.confirm.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.arrow_forward_rounded, size: 18.sp),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required FxTokens t,
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: t.text),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword ? _obscurePassword : false,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: t.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: t.textFaint),
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
            prefixIcon: Icon(icon, size: 20.sp),
            prefixIconColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.focused) ? cs.primary : t.textFaint,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 19.sp,
                      color: t.textFaint,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCard(FxTokens t, AppLocalizations l10n) {
    return FxCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FxIconBadge(icon: Icons.support_agent_rounded, tone: FxTokens.indigo),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.donotHaveAccount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h3,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      l10n.contactAdmin,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: _openPartnershipSite,
            icon: Icon(Icons.business_center_rounded, size: 18.sp),
            label: Text(
              l10n.partnershipContact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.ink(FxTokens.blue),
              minimumSize: Size(double.infinity, math.max(44.0, 44.h)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────────

/// Translucent pill button used on the brand gradient.
class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.24))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          child: child,
        ),
      ),
    );
  }
}

/// Light / dark switch in the glass style (same action as ThemeToggleButton: ThemeProvider.toggleTheme).
class _GlassThemeSwitch extends StatelessWidget {
  const _GlassThemeSwitch();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Semantics(
      button: true,
      toggled: isDark,
      child: GestureDetector(
        onTap: () => themeProvider.toggleTheme(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 58.w,
          height: 32.w,
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
            borderRadius: BorderRadius.circular(FxTokens.rPill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 16.sp,
                color: isDark ? FxTokens.indigo : FxTokens.amber,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _DecorCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// One row of the language sheet.
class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({required this.flag, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: selected ? t.soft(FxTokens.blue) : t.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        side: BorderSide(color: selected ? FxTokens.blue.withValues(alpha: 0.45) : t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border),
                ),
                child: Text(flag, style: TextStyle(fontSize: 20.sp)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
              ),
              SizedBox(width: 8.w),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded, size: 22.sp, color: t.ink(FxTokens.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
