import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Building blocks shared by the v2 "Bố trí công việc" screens (toolbars, chips, avatars, save bar…).
/// Presentation only — no data or business logic lives here.

// ─── Helpers ────────────────────────────────────────────────────────────────

/// "Nguyễn Văn An" → "NA". Safe for empty names (v1 crashed on `substring(0, 1)` of an empty name).
String waInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

const List<Color> _avatarTones = [
  FxTokens.blue,
  FxTokens.indigo,
  FxTokens.emerald,
  FxTokens.violet,
  FxTokens.cyan,
  FxTokens.amber,
  FxTokens.orange,
];

/// Stable tone for a person (same name → same colour).
Color waToneFor(String seed) {
  if (seed.isEmpty) return FxTokens.slate;
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarTones[h % _avatarTones.length];
}

/// 3 → "3", 2.5 → "2.5" (no trailing ".0").
String waNum(num v) {
  final d = v.toDouble();
  return d.truncateToDouble() == d ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
}

/// Track colour of the pill tab bars (darker than cards in both themes).
Color waTrack(FxTokens t) => t.dark ? Color.lerp(t.bg, t.card, 0.5)! : t.track;

// ─── Avatar & person chips ──────────────────────────────────────────────────

class WaAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? tone;

  const WaAvatar({super.key, required this.name, this.size = 36, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final c = tone ?? waToneFor(name);
    final initials = waInitials(name);
    final s = size.w;
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft(c), shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: s * 0.52, color: t.ink(c))
          : Text(
              initials,
              maxLines: 1,
              style: TextStyle(fontSize: s * 0.36, fontWeight: FontWeight.w800, color: t.ink(c), height: 1),
            ),
    );
  }
}

/// Assigned person: avatar + name (+ remove ×).
class WaPersonChip extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;

  const WaPersonChip({super.key, required this.name, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      height: 30.w,
      padding: EdgeInsets.fromLTRB(3.w, 0, onRemove == null ? 11.w : 3.w, 0),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(FxTokens.rPill),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaAvatar(name: name, size: 24),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: t.text, height: 1.2),
            ),
          ),
          if (onRemove != null) ...[
            SizedBox(width: 2.w),
            Material(
              type: MaterialType.transparency,
              child: InkResponse(
                onTap: onRemove,
                radius: 14.w,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(Icons.close_rounded, size: 14.sp, color: t.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+" chip (icon only when [label] is null).
class WaAddChip extends StatelessWidget {
  final String? label;
  final VoidCallback onTap;
  final Color tone;

  const WaAddChip({super.key, this.label, required this.onTap, this.tone = FxTokens.blue});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fg = t.ink(tone);
    return Material(
      color: t.soft(tone),
      shape: StadiumBorder(side: BorderSide(color: tone.withValues(alpha: 0.35))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 30.w,
          width: label == null ? 30.w : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 11.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16.sp, color: fg),
                if (label != null) ...[
                  SizedBox(width: 4.w),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: fg, height: 1.2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Toolbar controls ───────────────────────────────────────────────────────

/// Bordered chip opening a date / month picker.
class WaDateChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  const WaDateChip({super.key, required this.label, this.onTap, this.icon = Icons.calendar_today_rounded});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: t.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 38.h,
          child: Padding(
            padding: EdgeInsets.fromLTRB(11.w, 0, 7.w, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14.sp, color: t.ink(FxTokens.blue)),
                SizedBox(width: 7.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                      fontFeatures: FxTokens.tabular,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Icon(Icons.expand_more_rounded, size: 16.sp, color: t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square bordered icon button of the toolbars (shows a spinner when [loading]).
class WaToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;
  final Color? tone;

  const WaToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.loading = false,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fg = onTap == null ? t.textFaint : (tone == null ? t.text : t.ink(tone!));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: t.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38.h,
            height: 38.h,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 16.h,
                      height: 16.h,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.ink(tone ?? FxTokens.blue)),
                    )
                  : Icon(icon, size: 18.sp, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round action inside cards (delete, add…).
class WaIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color tone;

  const WaIconAction({super.key, required this.icon, required this.tooltip, this.onTap, this.tone = FxTokens.slate});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.soft(tone),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 32.w,
            height: 32.w,
            child: Icon(icon, size: 17.sp, color: onTap == null ? t.textFaint : t.ink(tone)),
          ),
        ),
      ),
    );
  }
}

/// Pill tab bar (same look as the other v2 screens) bound to a [TabController].
class WaPillTabBar extends StatelessWidget {
  final TabController? controller;
  final List<({IconData icon, String label})> tabs;
  final ValueChanged<int>? onTap;
  final bool dense;

  const WaPillTabBar({super.key, required this.controller, required this.tabs, this.onTap, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fs = (dense ? 12 : 12.5).sp;
    return Container(
      height: (dense ? 38 : 42).h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: waTrack(t), borderRadius: BorderRadius.circular(13.r)),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10.r),
        indicator: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))],
        ),
        labelColor: t.text,
        unselectedLabelColor: t.textMuted,
        labelPadding: EdgeInsets.zero,
        labelStyle: TextStyle(fontSize: fs, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: fs, fontWeight: FontWeight.w500),
        tabs: [
          for (final tb in tabs)
            Tab(
              height: (dense ? 32 : 36).h,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tb.icon, size: (dense ? 14 : 15).sp),
                    SizedBox(width: 5.w),
                    Flexible(child: Text(tb.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Value-based twin of [WaPillTabBar] (sliding pill, optional count bubble per segment).
class WaSegmented<T> extends StatelessWidget {
  final List<WaViewOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const WaSegmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final idx = options.indexWhere((o) => o.value == value);
    return Container(
      height: 38.h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: waTrack(t), borderRadius: BorderRadius.circular(13.r)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              if (idx >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: w * idx,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final o in options)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(o.value),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (o.icon != null) ...[
                                  Icon(o.icon, size: 14.sp, color: o.value == value ? t.text : t.textMuted),
                                  SizedBox(width: 5.w),
                                ],
                                Flexible(
                                  child: Text(
                                    o.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: o.value == value ? FontWeight.w700 : FontWeight.w500,
                                      color: o.value == value ? t.text : t.textMuted,
                                    ),
                                  ),
                                ),
                                if (o.count != null) ...[
                                  SizedBox(width: 5.w),
                                  Container(
                                    constraints: BoxConstraints(minWidth: 18.w),
                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: o.value == value ? t.soft(FxTokens.blue) : t.card.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(FxTokens.rPill),
                                    ),
                                    child: Text(
                                      '${o.count}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                        color: o.value == value ? t.ink(FxTokens.blue) : t.textMuted,
                                        fontFeatures: FxTokens.tabular,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WaViewOption<T> {
  final T value;
  final String label;
  final int? count;
  final IconData? icon;
  const WaViewOption(this.value, this.label, {this.count, this.icon});
}

/// Equal-width view switcher chips with a count bubble (replaces the v1 "view" dropdowns).
class WaViewChips<T> extends StatelessWidget {
  final List<WaViewOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const WaViewChips({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(width: 6.w),
          Expanded(child: _chip(t, options[i])),
        ],
      ],
    );
  }

  Widget _chip(FxTokens t, WaViewOption<T> o) {
    final sel = o.value == value;
    final fg = sel ? Colors.white : t.textMuted;
    return Material(
      color: sel ? FxTokens.blue : t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11.r),
        side: BorderSide(color: sel ? FxTokens.blue : t.border),
      ),
      child: InkWell(
        onTap: () => onChanged(o.value),
        child: SizedBox(
          height: 36.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (o.icon != null) ...[Icon(o.icon, size: 14.sp, color: fg), SizedBox(width: 5.w)],
                Flexible(
                  child: Text(
                    o.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                      color: sel ? Colors.white : t.text,
                    ),
                  ),
                ),
                if (o.count != null) ...[
                  SizedBox(width: 5.w),
                  Container(
                    constraints: BoxConstraints(minWidth: 20.w),
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white.withValues(alpha: 0.22) : t.cardAlt,
                      borderRadius: BorderRadius.circular(FxTokens.rPill),
                      border: sel ? null : Border.all(color: t.border),
                    ),
                    child: Text(
                      '${o.count}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : t.textMuted,
                        fontFeatures: FxTokens.tabular,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary strip ──────────────────────────────────────────────────────────

class WaStat {
  final String label;
  final String value;
  final String? suffix;
  final Color tone;
  const WaStat(this.label, this.value, {this.suffix, required this.tone});
}

/// One card with 2–4 compact figures separated by hairlines.
class WaStatStrip extends StatelessWidget {
  final List<WaStat> stats;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;

  const WaStatStrip({super.key, required this.stats, this.footer, this.margin});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return FxCard(
      margin: margin ?? EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, thickness: 1, color: t.divider),
                  Expanded(child: _cell(t, stats[i])),
                ],
              ],
            ),
          ),
          if (footer != null) Padding(padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0), child: footer!),
        ],
      ),
    );
  }

  Widget _cell(FxTokens t, WaStat s) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: s.tone, shape: BoxShape.circle),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: s.value, style: t.num(18.sp)),
                  if (s.suffix != null)
                    TextSpan(
                      text: s.suffix,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: t.textMuted,
                        fontWeight: FontWeight.w700,
                        fontFeatures: FxTokens.tabular,
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
}

// ─── Save bar ───────────────────────────────────────────────────────────────

/// Bottom bar with a message and the primary "Lưu" button.
class WaSaveBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool saving;
  final VoidCallback? onSave;
  final String label;
  final IconData icon;
  final Color tone;

  const WaSaveBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.saving,
    required this.onSave,
    this.label = 'Lưu',
    this.icon = Icons.edit_note_rounded,
    this.tone = FxTokens.amber,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: t.dark
            ? const []
            : const [BoxShadow(color: Color(0x120F172A), blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 34),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                if (subtitle != null) ...[
                  SizedBox(height: 1.h),
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: Size(92.w, 42.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            icon: saving
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.textMuted))
                : Icon(Icons.check_rounded, size: 18.sp),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

// ─── Rows used in lists & sheets ────────────────────────────────────────────

/// Person row: avatar, name, subtitle, trailing pills / widget.
class WaPersonRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final List<Widget> pills;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? avatarTone;

  const WaPersonRow({
    super.key,
    required this.name,
    this.subtitle,
    this.pills = const [],
    this.trailing,
    this.onTap,
    this.avatarTone,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: Row(
        children: [
          WaAvatar(name: name, size: 38, tone: avatarTone),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name.isEmpty ? '—' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                ],
              ],
            ),
          ),
          for (final p in pills) ...[
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 120.w),
              child: p,
            ),
          ],
          if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: BorderRadius.circular(FxTokens.rTile), onTap: onTap, child: row),
    );
  }
}

/// Vehicle row: tinted truck badge, plate, name, type pill, trailing widget.
class WaVehicleRow extends StatelessWidget {
  final String plate;
  final String? name;
  final String? type;
  final IconData icon;
  final Color tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  const WaVehicleRow({
    super.key,
    required this.plate,
    this.name,
    this.type,
    this.icon = Icons.local_shipping_rounded,
    this.tone = FxTokens.blue,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 38),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plate.isEmpty ? '—' : plate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.h3.copyWith(fontFeatures: FxTokens.tabular, letterSpacing: 0.2),
                ),
                if (name != null && name!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(name!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                ],
              ],
            ),
          ),
          if (type != null && type!.isNotEmpty) ...[
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 110.w),
              child: FxPill(label: type!, tone: FxTokens.slate),
            ),
          ],
          if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: BorderRadius.circular(FxTokens.rTile), onTap: onTap, child: row),
    );
  }
}

/// "12 xe chưa được bố trí" style caption above a list.
class WaListCaption extends StatelessWidget {
  final IconData icon;
  final String text;

  const WaListCaption({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(2.w, 0, 2.w, 8.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: t.textFaint),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.small),
          ),
        ],
      ),
    );
  }
}

// ─── Sheets ─────────────────────────────────────────────────────────────────

class WaSheetHandle extends StatelessWidget {
  const WaSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Header of a bottom sheet: badge, title, subtitle, close button.
class WaSheetHeader extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;

  const WaSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.tone = FxTokens.blue,
    this.subtitle,
    this.trailing,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 2.h, 10.w, 12.h),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 38),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.h2.copyWith(fontSize: 16.sp),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.tiny),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 6.w), trailing!],
          if (onClose != null) ...[
            SizedBox(width: 2.w),
            IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close_rounded, size: 20.sp, color: t.textMuted),
              style: IconButton.styleFrom(backgroundColor: t.cardAlt),
            ),
          ],
        ],
      ),
    );
  }
}

/// Toggle pill used for skill filters (calls [onSelected] with the new value, like FilterChip).
class WaFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const WaFilterPill({super.key, required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: selected ? t.soft(FxTokens.blue) : t.cardAlt,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(side: BorderSide(color: selected ? FxTokens.blue.withValues(alpha: 0.5) : t.border)),
      child: InkWell(
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14.sp, color: t.ink(FxTokens.blue)),
                SizedBox(width: 4.w),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? t.ink(FxTokens.blue) : t.text,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────────────

/// Skeleton of a list screen: optional summary block + [count] cards.
class WaListSkeleton extends StatelessWidget {
  final int count;
  final double itemHeight;
  final bool summary;

  const WaListSkeleton({super.key, this.count = 4, this.itemHeight = 128, this.summary = true});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (summary) ...[FxSkeleton(height: 70.h, radius: 18), SizedBox(height: 12.h)],
        for (var i = 0; i < count; i++) ...[FxSkeleton(height: itemHeight.h, radius: 18), SizedBox(height: 10.h)],
      ],
    );
  }
}
