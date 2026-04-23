import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/theme/app_theme.dart';
import 'package:nguyenanh/core/theme/theme_provider.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/auth/data/services/auth_service.dart';

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Nguyên Anh',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          navigatorKey: ApiClient.navigatorKey,
          locale: languageProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RootHandler(),
        );
      },
    );
  }
}

class RootHandler extends StatefulWidget {
  const RootHandler({super.key});

  @override
  State<RootHandler> createState() => _RootHandlerState();
}

class _RootHandlerState extends State<RootHandler> {
  @override
  void initState() {
    super.initState();
    _handleStartUp();
  }

  Future<void> _handleStartUp() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SelectionPage()),
        );
      }
      return;
    }

    // Token exists — proactively refresh before entering app
    try {
      final authService = AuthService(ApiClient.refreshDio);
      final result = await authService.refresh();

      await prefs.setString('access_token', result.accessToken);
      await prefs.setInt('user_id', result.userId);
      await prefs.setString('user_full_name', result.fullName);
      await prefs.setString('user_role', result.role);
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      debugPrint('[Startup] Refresh failed: $e');
      // Refresh cookie expired or network error — clear session, go to login
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('user_full_name');
      await prefs.remove('user_role');
      await prefs.setBool('is_logged_in', false);
      ApiClient.cookieJar.deleteAll();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SelectionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
