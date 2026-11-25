import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';

/// Building blocks of the redesigned (v2) UI, shared by every v2 screen of the app.

// ─── Card ───────────────────────────────────────────────────────────────────

class FxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const FxCard({super.key, required this.child, this.padding, this.margin, this.onTap, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final body = Padding(padding: padding ?? EdgeInsets.all(14.w), child: child);
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        border: Border.all(color: borderColor ?? t.border.withValues(alpha: 0.7)),
        boxShadow: t.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// Title row of a card: tinted icon badge + title (+ subtitle) + trailing.
class FxSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color tone;
  final Widget? trailing;

  const FxSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = FxTokens.blue,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 32),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.h2),
                if (subtitle != null) ...[
                  SizedBox(height: 1.h),
                  Text(subtitle!, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
        ],
      ),
    );
  }
}

class FxIconBadge extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final double size;

  const FxIconBadge({super.key, required this.icon, required this.tone, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(color: t.soft(tone), borderRadius: BorderRadius.circular(size.w * 0.32)),
      child: Icon(icon, size: size.w * 0.52, color: t.ink(tone)),
    );
  }
}

// ─── Pills / chips ──────────────────────────────────────────────────────────

class FxPill extends StatelessWidget {
  final String label;
  final Color tone;
  final IconData? icon;
  final bool solid;
  final bool dot;

  const FxPill({super.key, required this.label, required this.tone, this.icon, this.solid = false, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fg = solid ? Colors.white : t.ink(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: solid ? tone : t.soft(tone), borderRadius: BorderRadius.circular(FxTokens.rPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            SizedBox(width: 5.w),
          ],
          if (icon != null) ...[Icon(icon, size: 12.sp, color: fg), SizedBox(width: 4.w)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: fg, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Percentage change vs a reference (red when ≥ +10 %).
class FxDelta extends StatelessWidget {
  final double? cur;
  final double? base;
  final String label;

  const FxDelta({super.key, required this.cur, required this.base, required this.label});

  @override
  Widget build(BuildContext context) {
    if (cur == null || base == null || base! <= 0) return const SizedBox.shrink();
    final pct = (cur! - base!) / base! * 100;
    if (!pct.isFinite) return const SizedBox.shrink();
    final up = pct >= 0;
    final tone = pct >= 10 ? FxTokens.red : (up ? FxTokens.amber : FxTokens.emerald);
    return FxPill(
      icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      label: '${up ? '+' : ''}${NumberFormat('#,##0', 'vi').format(pct)}% $label',
      tone: tone,
    );
  }
}

// ─── Segmented control ──────────────────────────────────────────────────────

class FxSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? badge;
  const FxSegment(this.value, this.label, {this.icon, this.badge});
}

/// Sliding-pill segmented control (equal widths).
class FxSegmented<T> extends StatelessWidget {
  final List<FxSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool dense;

  const FxSegmented({super.key, required this.segments, required this.value, required this.onChanged, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final idx = segments.indexWhere((s) => s.value == value);
    final h = (dense ? 34 : 40).h;
    return Container(
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.dark ? const Color(0xFF0F172A) : const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / segments.length;
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
                    borderRadius: BorderRadius.circular(9.r),
                    boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
            Row(
              children: [
                for (final s in segments)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(s.value),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.icon != null) ...[
                              Icon(s.icon, size: 14.sp, color: s.value == value ? t.text : t.textMuted),
                              SizedBox(width: 4.w),
                            ],
                            Flexible(
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: (dense ? 11.5 : 12.5).sp,
                                  fontWeight: s.value == value ? FontWeight.w700 : FontWeight.w500,
                                  color: s.value == value ? t.text : t.textMuted,
                                ),
                              ),
                            ),
                            if (s.badge != null && s.badge! > 0) ...[
                              SizedBox(width: 4.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1),
                                decoration: BoxDecoration(color: FxTokens.red, borderRadius: BorderRadius.circular(8)),
                                child: Text('${s.badge}',
                                    style: TextStyle(fontSize: 9.5.sp, color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ─── KPI ────────────────────────────────────────────────────────────────────

class FxKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color tone;
  final Widget? footer;
  final String? hint;

  const FxKpi({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    required this.tone,
    this.footer,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return FxCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(12.w),
      onTap: hint == null || hint!.isEmpty ? null : () => showFxHint(context, label, hint!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FxIconBadge(icon: icon, tone: tone, size: 28),
              const Spacer(),
              if (hint != null && hint!.isNotEmpty) Icon(Icons.info_outline_rounded, size: 14.sp, color: t.textFaint),
            ],
          ),
          SizedBox(height: 10.h),
          Text(label, style: t.small, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 3.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: value, style: t.num(20.sp)),
              if (unit != null && value != '—')
                TextSpan(text: ' $unit', style: TextStyle(fontSize: 11.5.sp, color: t.textMuted, fontWeight: FontWeight.w600)),
            ])),
          ),
          if (sub != null) ...[
            SizedBox(height: 3.h),
            Text(sub!, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (footer != null) ...[SizedBox(height: 6.h), footer!],
        ],
      ),
    );
  }
}

/// Grid with a fixed number of columns; children keep their own height (rows align to the tallest).
class FxGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double? gap;

  const FxGrid({super.key, required this.children, this.columns = 2, this.gap});

  @override
  Widget build(BuildContext context) {
    final g = gap ?? 10.w;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: g));
        cells.add(Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()));
      }
      if (i > 0) rows.add(SizedBox(height: g));
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
    }
    return Padding(padding: EdgeInsets.only(bottom: 12.h), child: Column(children: rows));
  }
}

void showFxHint(BuildContext context, String title, String text) {
  final t = FxTokens.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: t.card,
    builder: (_) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.h2),
            SizedBox(height: 8.h),
            Text(text, style: t.body),
          ],
        ),
      ),
    ),
  );
}

// ─── Pager ──────────────────────────────────────────────────────────────────

/// Slice of a list for page [page] (0-based).
List<T> fxPage<T>(List<T> all, int page, int size) {
  if (all.isEmpty) return const [];
  final pages = (all.length / size).ceil();
  final p = page.clamp(0, pages - 1);
  return all.sublist(p * size, math.min(all.length, (p + 1) * size));
}

/// "1–5 / 23   ‹ 1 2 3 ›" pager. Hidden when everything fits on one page.
class FxPager extends StatelessWidget {
  final int page;
  final int total;
  final int size;
  final ValueChanged<int> onChanged;

  const FxPager({super.key, required this.page, required this.total, required this.size, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pages = (total / size).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    final t = FxTokens.of(context);
    final p = page.clamp(0, pages - 1);
    final from = p * size + 1, to = math.min(total, (p + 1) * size);

    // window of at most 5 page numbers around the current one
    var start = math.max(0, p - 2);
    final end = math.min(pages - 1, start + 4);
    start = math.max(0, end - 4);

    Widget btn(Widget child, VoidCallback? onTap, {bool active = false}) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Material(
            color: active ? FxTokens.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: onTap,
              child: SizedBox(width: 30.w, height: 30.w, child: Center(child: child)),
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Row(
        children: [
          Text('$from–$to / $total', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
          const Spacer(),
          btn(Icon(Icons.chevron_left_rounded, size: 18.sp, color: p > 0 ? t.text : t.textFaint), p > 0 ? () => onChanged(p - 1) : null),
          for (var i = start; i <= end; i++)
            btn(
              Text('${i + 1}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: i == p ? Colors.white : t.textMuted,
                    fontFeatures: FxTokens.tabular,
                  )),
              i == p ? null : () => onChanged(i),
              active: i == p,
            ),
          btn(Icon(Icons.chevron_right_rounded, size: 18.sp, color: p < pages - 1 ? t.text : t.textFaint),
              p < pages - 1 ? () => onChanged(p + 1) : null),
        ],
      ),
    );
  }
}

// ─── States ─────────────────────────────────────────────────────────────────

class FxEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const FxEmpty({super.key, this.icon = Icons.inbox_outlined, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(color: t.cardAlt, shape: BoxShape.circle, border: Border.all(color: t.border)),
            child: Icon(icon, size: 24.sp, color: t.textFaint),
          ),
          SizedBox(height: 10.h),
          Text(title, textAlign: TextAlign.center, style: t.h3),
          if (message != null) ...[
            SizedBox(height: 4.h),
            Text(message!, textAlign: TextAlign.center, style: t.small),
          ],
          if (action != null) ...[SizedBox(height: 12.h), action!],
        ],
      ),
    );
  }
}

class FxBanner extends StatelessWidget {
  final String text;
  final Color tone;
  final IconData icon;
  final String? title;

  const FxBanner({super.key, required this.text, this.tone = FxTokens.amber, this.icon = Icons.info_outline_rounded, this.title});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: t.soft(tone),
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: t.ink(tone)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: t.ink(tone))),
                  SizedBox(height: 2.h),
                ],
                Text(text, style: TextStyle(fontSize: 12.sp, color: t.ink(tone), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering placeholder block.
class FxSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const FxSkeleton({super.key, required this.height, this.width, this.radius = 12});

  @override
  State<FxSkeleton> createState() => _FxSkeletonState();
}

class _FxSkeletonState extends State<FxSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final base = t.dark ? const Color(0xFF1A2438) : const Color(0xFFE8EDF4);
    final hi = t.dark ? const Color(0xFF243049) : const Color(0xFFF5F7FA);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final x = _c.value * 3 - 1;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [base, hi, base],
            ),
          ),
        );
      },
    );
  }
}

/// Generic loading layout: a header block, a 2×2 grid, and a tall block.
class FxLoadingView extends StatelessWidget {
  const FxLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(14.w),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FxSkeleton(height: 120.h, radius: 18),
        SizedBox(height: 12.h),
        Row(children: [
          Expanded(child: FxSkeleton(height: 96.h)),
          SizedBox(width: 10.w),
          Expanded(child: FxSkeleton(height: 96.h)),
        ]),
        SizedBox(height: 10.h),
        Row(children: [
          Expanded(child: FxSkeleton(height: 96.h)),
          SizedBox(width: 10.w),
          Expanded(child: FxSkeleton(height: 96.h)),
        ]),
        SizedBox(height: 12.h),
        FxSkeleton(height: 240.h, radius: 18),
      ],
    );
  }
}

// ─── Misc ───────────────────────────────────────────────────────────────────

/// Circular gauge (0–100) with a centred label.
class FxGauge extends StatelessWidget {
  final double? value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;

  const FxGauge({super.key, required this.value, required this.size, this.stroke = 8, required this.color, this.center});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(value: value, track: t.track, color: color, stroke: stroke),
        child: Center(child: center),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double? value;
  final Color track;
  final Color color;
  final double stroke;

  _GaugePainter({required this.value, required this.track, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, p..color = track);
    if (value != null) {
      canvas.drawArc(rect, start, sweep * (value! / 100).clamp(0.0, 1.0), false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value || old.color != color || old.track != track;
}

/// Thin stacked bar of parts (e.g. time split, activity split).
class FxStackBar extends StatelessWidget {
  final List<({double value, Color color})> parts;
  final double height;

  const FxStackBar({super.key, required this.parts, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final total = parts.fold<double>(0, (a, p) => a + p.value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? Container(color: t.track)
            : Row(
                children: [
                  for (final p in parts)
                    if (p.value > 0) Expanded(flex: math.max(1, (p.value / total * 1000).round()), child: Container(color: p.color)),
                ],
              ),
      ),
    );
  }
}

/// Small legend entry: coloured dot + label (+ value).
class FxLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String? value;
  final bool line;

  const FxLegend({super.key, required this.color, required this.label, this.value, this.line = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: line ? 14 : 8,
          height: line ? 3 : 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        SizedBox(width: 5.w),
        Text(label, style: t.tiny),
        if (value != null) ...[
          SizedBox(width: 4.w),
          Text(value!, style: t.tiny.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular)),
        ],
      ],
    );
  }
}

/// Search field in the v2 style.
class FxSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const FxSearchField({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: t.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: t.small,
        prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
        filled: true,
        fillColor: t.cardAlt,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: t.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: t.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: FxTokens.blue, width: 1.4),
        ),
      ),
    );
  }
}

/// Label / value row used in detail sheets.
class FxInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const FxInfoTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: t.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: t.textFaint),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: t.overline),
                SizedBox(height: 3.h),
                Text(value, style: t.h3.copyWith(fontFeatures: FxTokens.tabular)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round white button floating over a map (hairline border, soft shadow).
class FxMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const FxMapButton({super.key, required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.card,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38.w,
            height: 38.w,
            child: Icon(icon, size: 20.sp, color: onTap == null ? t.textFaint : t.text),
          ),
        ),
      ),
    );
  }
}
