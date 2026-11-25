import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Design tokens of the redesigned app UI (v2). Slate neutrals + the app's blue, light and dark.
class FxTokens {
  final bool dark;
  const FxTokens._(this.dark);

  static FxTokens of(BuildContext context) => FxTokens._(Theme.of(context).brightness == Brightness.dark);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  Color get bg => dark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);
  Color get card => dark ? const Color(0xFF131C2E) : Colors.white;
  Color get cardAlt => dark ? const Color(0xFF1A2438) : const Color(0xFFF8FAFC);
  Color get border => dark ? const Color(0xFF243049) : const Color(0xFFE2E8F0);
  Color get divider => dark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F7);
  Color get text => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textMuted => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textFaint => dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get track => dark ? const Color(0xFF243049) : const Color(0xFFE2E8F0);

  List<BoxShadow> get shadow => dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, 6)),
        ];

  // ── Semantic colours ──────────────────────────────────────────────────────
  static const blue = Color(0xFF2563EB);
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF059669);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFD97706);
  static const yellow = Color(0xFFCA8A04);
  static const red = Color(0xFFDC2626);
  static const violet = Color(0xFF7C3AED);
  static const cyan = Color(0xFF0891B2);
  static const slate = Color(0xFF64748B);
  static const orange = Color(0xFFF97316);

  /// Soft background for a tone (pill, icon badge).
  Color soft(Color c) => c.withValues(alpha: dark ? 0.18 : 0.10);

  /// Readable foreground of a tone on its soft background.
  Color ink(Color c) => dark ? Color.lerp(c, Colors.white, 0.35)! : c;

  // ── Radii ─────────────────────────────────────────────────────────────────
  static double get rCard => 18.r;
  static double get rTile => 14.r;
  static double get rPill => 999;

  // ── Typography ────────────────────────────────────────────────────────────
  static const tabular = [FontFeature.tabularFigures()];

  TextStyle get h1 => TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.4, height: 1.15);
  TextStyle get h2 => TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.1);
  TextStyle get h3 => TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: text);
  TextStyle get body => TextStyle(fontSize: 13.sp, color: text, height: 1.4);
  TextStyle get small => TextStyle(fontSize: 11.5.sp, color: textMuted, height: 1.35);
  TextStyle get tiny => TextStyle(fontSize: 10.5.sp, color: textMuted, height: 1.3);
  TextStyle get overline =>
      TextStyle(fontSize: 10.sp, color: textFaint, fontWeight: FontWeight.w700, letterSpacing: 0.8);
  TextStyle num(double size, {Color? color, FontWeight weight = FontWeight.w800}) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        fontFeatures: tabular,
        letterSpacing: -0.3,
        height: 1.1,
      );
}
