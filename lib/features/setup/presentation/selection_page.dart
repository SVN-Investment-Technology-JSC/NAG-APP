import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/theme_toggle_button.dart';
import 'package:nguyenanh/features/auth/data/services/auth_service.dart';
import 'package:nguyenanh/features/auth/data/services/auth_storage_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthStorageService _authStorage = AuthStorageService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

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
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterDetails)));
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginGenericError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.selectLanguage,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: Text('🇻🇳', style: TextStyle(fontSize: 24.sp)),
                title: Text(l10n.vietnamese),
                trailing: languageProvider.locale.languageCode == 'vi'
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  languageProvider.setLocale(const Locale('vi'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Text('🇺🇸', style: TextStyle(fontSize: 24.sp)),
                title: Text(l10n.english),
                trailing: languageProvider.locale.languageCode == 'en'
                    ? const Icon(Icons.check_circle, color: Colors.green)
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.fleetSelection,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18.sp)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _showLanguagePicker,
          icon: Icon(Icons.language_rounded, color: colorScheme.primary),
        ),
        actions: [
          const ThemeToggleButton(),
          SizedBox(width: 16.w),
        ],
      ),
      body: Stack(
        children: [
          // BACKGROUND ACCENT
          Positioned(
            top: -100.h,
            right: -50.w,
            child: Container(
              width: 300.w,
              height: 300.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary
                    .withValues(alpha: isDark ? 0.05 : 0.03),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER SECTION
                  Center(
                    child: Column(
                      children: [
                        SizedBox(height: 1.h),
                        Container(
                          width: 160.w,
                          height: 160.w,
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : colorScheme.primary
                                    .withValues(alpha: 0.03),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                    alpha: isDark ? 0.25 : 0.08),
                                blurRadius: 50,
                                offset: const Offset(0, 15),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(80.r),
                            child: Image.asset(
                              'assets/images/vehicle_fleet.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.local_shipping_rounded,
                                size: 70.sp,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // LOGIN FORM CARD
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 450.w),
                      child: Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              l10n.username,
                              _usernameController,
                              Icons.person_outline_rounded,
                            ),
                            SizedBox(height: 20.h),
                            _buildTextField(
                              l10n.password,
                              _passwordController,
                              Icons.lock_open_rounded,
                              isPassword: true,
                            ),
                            SizedBox(height: 20.h),
    
                            // REMEMBER ME
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _rememberMe = !_rememberMe),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22.w,
                                    height: 22.w,
                                    decoration: BoxDecoration(
                                      color: _rememberMe
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                        color: _rememberMe
                                            ? colorScheme.primary
                                            : colorScheme.onSurface
                                                .withValues(alpha: 0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: _rememberMe
                                        ? Icon(Icons.check_rounded,
                                            color: Colors.white, size: 14.sp)
                                        : null,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  l10n.rememberMe,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
    
                            SizedBox(height: 32.h),
    
                            // CONFIRM BUTTON
                            GestureDetector(
                              onTap: _isLoading ? null : _onConfirm,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: double.infinity,
                                height: 60.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  gradient: LinearGradient(
                                    colors: _isLoading
                                        ? [
                                            colorScheme.primary
                                                .withValues(alpha: 0.6),
                                            colorScheme.primary
                                                .withValues(alpha: 0.4)
                                          ]
                                        : [
                                            colorScheme.primary,
                                            const Color(0xFF1E3A8A)
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    if (!_isLoading)
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      )
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24.w,
                                          height: 24.w,
                                          child: const CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          l10n.confirm.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
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

                  SizedBox(height: 32.h),

                  // REGISTRATION HELP (For Apple Review)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        children: [
                          Text(
                            l10n.donotHaveAccount,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            l10n.contactAdmin,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse('https://nguyenanhgroup.vn/');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: Icon(Icons.business_center_rounded, size: 18.sp),
                            label: Text(l10n.partnershipContact),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // FOOTER
                  Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        'v1.0.0 • NGUYÊN ANH',
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                size: 20.sp,
                color: colorScheme.primary.withValues(alpha: 0.7)),
            hintText: '$label...',
            hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            filled: true,
            fillColor: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : colorScheme.primary.withValues(alpha: 0.03),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  width: 1.5),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18.sp,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
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
}
