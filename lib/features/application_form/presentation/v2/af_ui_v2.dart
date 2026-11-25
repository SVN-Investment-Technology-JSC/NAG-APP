import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Presentation-only helpers shared by the v2 "Đơn từ" screens. No business logic here.

class AfTone {
  AfTone._();

  /// pending = amber, approved = emerald, rejected / canceled = red.
  static Color status(String status) {
    switch (status) {
      case 'approved':
        return FxTokens.emerald;
      case 'rejected':
      case 'canceled':
        return FxTokens.red;
      default:
        return FxTokens.amber;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'canceled':
        return Icons.block_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

/// Initial(s) of a person's name for an avatar ("Nguyễn Văn An" → "A"); safe for empty names.
String afInitial(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.last.characters.first.toUpperCase();
}

AppBar afAppBar(BuildContext context, {required String title, String? subtitle, List<Widget>? actions}) {
  final t = FxTokens.of(context);
  return AppBar(
    backgroundColor: t.bg,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    centerTitle: false,
    foregroundColor: t.text,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 18.sp)),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
        ],
      ],
    ),
    actions: actions,
  );
}

/// Sticky bottom action bar (card surface, hairline top border, safe-area aware).
class AfBottomBar extends StatelessWidget {
  final Widget child;

  const AfBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: t.dark ? const [] : const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h), child: child),
      ),
    );
  }
}

class AfSpinner extends StatelessWidget {
  final Color color;
  const AfSpinner({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 18.w, height: 18.w, child: CircularProgressIndicator(strokeWidth: 2, color: color));
}

/// Static label above a form control.
class AfField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;

  const AfField({super.key, required this.label, required this.child, this.required = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label),
                if (required) TextSpan(text: ' *', style: TextStyle(color: t.ink(FxTokens.red))),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: t.textMuted),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Avatar circle with the person's initial.
class AfAvatar extends StatelessWidget {
  final String? name;
  final Color tone;
  final double size;

  const AfAvatar({super.key, required this.name, this.tone = FxTokens.blue, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft(tone), shape: BoxShape.circle),
      child: Text(
        afInitial(name),
        style: TextStyle(fontSize: (size * 0.4).sp, fontWeight: FontWeight.w800, color: t.ink(tone)),
      ),
    );
  }
}

/// Small calendar block: month on top, day number below.
class AfDateBlock extends StatelessWidget {
  final DateTime? date;
  final Color tone;

  const AfDateBlock({super.key, required this.date, required this.tone});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final d = date;
    return Container(
      width: 46.w,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: t.soft(tone),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: d == null
          ? Icon(Icons.event_rounded, size: 20.sp, color: t.ink(tone))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TH ${d.month}', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: t.ink(tone), letterSpacing: 0.4)),
                SizedBox(height: 1.h),
                Text('${d.day}'.padLeft(2, '0'), style: t.num(18.sp, color: t.ink(tone))),
              ],
            ),
    );
  }
}

class AfDialogTitle extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;

  const AfDialogTitle({super.key, required this.icon, required this.tone, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Row(
      children: [
        FxIconBadge(icon: icon, tone: tone, size: 34),
        SizedBox(width: 10.w),
        Expanded(child: Text(title, style: t.h2.copyWith(fontSize: 16.sp))),
      ],
    );
  }
}
