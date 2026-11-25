import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nguyenanh/core/theme/app_colors.dart';

/// Redesigned app-wide theme (v2): slate neutrals + brand blue, flat cards with hairline borders,
/// consistent radii, stronger typography. The original theme stays in app_theme.dart (v1).
class AppThemeV2 {
  static const Color brand = Color(0xFF2563EB);
  static const Color brandDark = Color(0xFF60A5FA);
  static const Color emerald = Color(0xFF10B981);
  static const Color danger = Color(0xFFDC2626);

  // Light neutrals (slate)
  static const _lBg = Color(0xFFF1F5F9);
  static const _lSurface = Colors.white;
  static const _lText = Color(0xFF0F172A);
  static const _lMuted = Color(0xFF64748B);
  static const _lBorder = Color(0xFFE2E8F0);

  // Dark neutrals
  static const _dBg = Color(0xFF0B1220);
  static const _dSurface = Color(0xFF131C2E);
  static const _dText = Color(0xFFF1F5F9);
  static const _dMuted = Color(0xFF94A3B8);
  static const _dBorder = Color(0xFF243049);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light).copyWith(
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF1E3A8A),
      secondary: emerald,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD1FAE5),
      onSecondaryContainer: const Color(0xFF065F46),
      tertiary: const Color(0xFF10B981),
      tertiaryContainer: const Color(0xFFD1FAE5),
      onTertiaryContainer: const Color(0xFF065F46),
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: _lSurface,
      onSurface: _lText,
      onSurfaceVariant: _lMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF8FAFC),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE9EEF5),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: const Color(0xFFCBD5E1),
      outlineVariant: _lBorder,
      shadow: const Color(0xFF0F172A),
      inverseSurface: const Color(0xFF0F172A),
      onInverseSurface: const Color(0xFFF1F5F9),
      surfaceTint: Colors.transparent,
    );
    return _build(scheme, bg: _lBg, border: _lBorder, light: true);
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark).copyWith(
      primary: brandDark,
      onPrimary: const Color(0xFF0B1220),
      primaryContainer: const Color(0xFF1E3A8A),
      onPrimaryContainer: const Color(0xFFDBEAFE),
      secondary: const Color(0xFF34D399),
      onSecondary: const Color(0xFF052E16),
      secondaryContainer: const Color(0xFF064E3B),
      onSecondaryContainer: const Color(0xFFD1FAE5),
      tertiary: const Color(0xFF34D399),
      tertiaryContainer: const Color(0xFF064E3B),
      onTertiaryContainer: const Color(0xFFD1FAE5),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF450A0A),
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: _dSurface,
      onSurface: _dText,
      onSurfaceVariant: _dMuted,
      surfaceContainerLowest: _dBg,
      surfaceContainerLow: const Color(0xFF131C2E),
      surfaceContainer: const Color(0xFF1A2438),
      surfaceContainerHigh: const Color(0xFF243049),
      surfaceContainerHighest: const Color(0xFF2E3B57),
      outline: const Color(0xFF334155),
      outlineVariant: _dBorder,
      shadow: Colors.black,
      inverseSurface: const Color(0xFFF1F5F9),
      onInverseSurface: const Color(0xFF0F172A),
      surfaceTint: Colors.transparent,
    );
    return _build(scheme, bg: _dBg, border: _dBorder, light: false);
  }

  static ThemeData _build(ColorScheme cs, {required Color bg, required Color border, required bool light}) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: cs.brightness);
    final text = base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
    final tt = text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodySmall: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );
    final r12 = BorderRadius.circular(12);
    final r14 = BorderRadius.circular(14);
    final buttonShape = RoundedRectangleBorder(borderRadius: r12);
    final buttonText = (tt.labelLarge ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: tt,
      extensions: [light ? AppColorsExtension.light : AppColorsExtension.dark],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        iconTheme: IconThemeData(color: cs.onSurface),
        titleTextStyle: tt.titleLarge?.copyWith(fontSize: 19, color: cs.onSurface),
        systemOverlayStyle: light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: light ? 0.12 : 0.22),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        dividerColor: border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: buttonShape,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          side: BorderSide(color: border),
          foregroundColor: cs.onSurface,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText, foregroundColor: cs.primary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: r12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? const Color(0xFFF8FAFC) : const Color(0xFF1A2438),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: cs.error, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: border.withValues(alpha: 0.5))),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: border),
        backgroundColor: cs.surface,
        selectedColor: cs.primary.withValues(alpha: light ? 0.12 : 0.24),
        labelStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13),
        checkmarkColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: r12),
          side: BorderSide(color: border),
          selectedBackgroundColor: cs.primary.withValues(alpha: light ? 0.12 : 0.24),
          selectedForegroundColor: cs.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: tt.titleLarge?.copyWith(fontSize: 18),
        contentTextStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cs.surface,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: cs.outline,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x330F172A),
        shape: RoundedRectangleBorder(borderRadius: r14, side: BorderSide(color: border)),
        textStyle: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r14, side: BorderSide(color: border))),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: r12),
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        subtitleTextStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: r14),
        collapsedShape: RoundedRectangleBorder(borderRadius: r14),
        iconColor: cs.primary,
        collapsedIconColor: cs.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: light ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        contentTextStyle: TextStyle(color: light ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        actionTextColor: light ? const Color(0xFF93C5FD) : brand,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: r14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.primary.withValues(alpha: 0.12),
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cs.primary : null),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : null),
      ),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      badgeTheme: BadgeThemeData(backgroundColor: danger, textColor: Colors.white),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: cs.primary,
        headerForegroundColor: cs.onPrimary,
        rangeSelectionBackgroundColor: cs.primary.withValues(alpha: 0.12),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: cs.surface, surfaceTintColor: Colors.transparent),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
