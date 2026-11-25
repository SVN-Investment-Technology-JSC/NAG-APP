import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Presentation-only helpers shared by the v2 "Bảo trì xe" screens (tones, icons, app bar title,
/// sticky bottom bar, labelled form fields, filter track, workflow steps). No business logic here.

// ─── Tones & icons ──────────────────────────────────────────────────────────

class VmTone {
  VmTone._();

  /// draft = slate, submitted (chờ kiểm tra) = amber, reviewing (chờ phê duyệt) = blue,
  /// approved / completed = emerald, rejected / canceled = red.
  static Color status(String? status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return FxTokens.emerald;
      case 'rejected':
      case 'canceled':
        return FxTokens.red;
      case 'reviewing':
        return FxTokens.blue;
      case 'submitted':
        return FxTokens.amber;
      default:
        return FxTokens.slate;
    }
  }

  static IconData statusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.verified_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'canceled':
        return Icons.block_rounded;
      case 'reviewing':
        return Icons.manage_search_rounded;
      case 'submitted':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  static Color rank(int? rank) {
    switch (rank) {
      case 2:
        return FxTokens.blue;
      case 3:
        return FxTokens.amber;
      case 4:
        return FxTokens.red;
      default:
        return FxTokens.slate;
    }
  }

  static Color payment(String? status) {
    switch (status) {
      case 'paid':
        return FxTokens.emerald;
      case 'partial':
        return FxTokens.amber;
      default:
        return FxTokens.slate;
    }
  }

  static IconData typeIcon(String? type) {
    switch (type) {
      case 'repair':
        return Icons.build_rounded;
      case 'inspection':
        return Icons.fact_check_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.car_repair_rounded;
    }
  }

  static String typeLabel(String? type) {
    switch (type) {
      case 'repair':
        return 'Sửa chữa';
      case 'inspection':
        return 'Kiểm tra';
      case 'other':
        return 'Khác';
      default:
        return 'Bảo dưỡng';
    }
  }

  /// Tone of a workflow / history action.
  static Color action(String action) {
    if (action.contains('reject') || action == 'delete') return FxTokens.red;
    if (action.contains('approve')) return FxTokens.emerald;
    if (action == 'submit') return FxTokens.blue;
    return FxTokens.slate;
  }

  static IconData actionIcon(String action) {
    if (action == 'delete') return Icons.delete_outline_rounded;
    if (action.contains('reject')) return Icons.close_rounded;
    if (action.contains('approve')) return Icons.check_rounded;
    if (action == 'submit') return Icons.send_rounded;
    if (action == 'create') return Icons.add_rounded;
    if (action == 'update') return Icons.edit_rounded;
    return Icons.circle_outlined;
  }
}

// ─── App bar ────────────────────────────────────────────────────────────────

/// Left-aligned bold title + small subtitle, used as `AppBar.title`.
class VmAppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const VmAppBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 18.sp)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
        ],
      ],
    );
  }
}

AppBar vmAppBar(BuildContext context, {required String title, String? subtitle, List<Widget>? actions}) {
  final t = FxTokens.of(context);
  return AppBar(
    backgroundColor: t.bg,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    centerTitle: false,
    foregroundColor: t.text,
    title: VmAppBarTitle(title: title, subtitle: subtitle),
    actions: actions,
  );
}

// ─── Sticky bottom bar ──────────────────────────────────────────────────────

class VmBottomBar extends StatelessWidget {
  final Widget child;

  const VmBottomBar({super.key, required this.child});

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
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          child: child,
        ),
      ),
    );
  }
}

/// White spinner sized for a button.
class VmButtonSpinner extends StatelessWidget {
  final Color color;
  const VmButtonSpinner({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 18.w, height: 18.w, child: CircularProgressIndicator(strokeWidth: 2, color: color));
  }
}

// ─── Form helpers ───────────────────────────────────────────────────────────

/// Static label above a form control.
class VmField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;

  const VmField({super.key, required this.label, required this.child, this.required = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
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

/// Tappable read-only "field" (date pickers…), styled like the themed inputs.
class VmPickerField extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool placeholder;
  final VoidCallback? onTap;

  const VmPickerField({super.key, required this.icon, required this.text, this.placeholder = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: t.cardAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            children: [
              Icon(icon, size: 17.sp, color: placeholder ? t.textFaint : t.ink(FxTokens.blue)),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
                    color: placeholder ? t.textFaint : t.text,
                    fontFeatures: FxTokens.tabular,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 18.sp, color: t.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Key / value row ────────────────────────────────────────────────────────

class VmKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final bool last;
  final Widget? trailing;

  const VmKeyValue({super.key, required this.label, required this.value, this.emphasis = false, this.last = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final empty = value.isEmpty;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: t.small),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 6,
            child: trailing != null
                ? Align(alignment: Alignment.centerRight, child: trailing)
                : Text(
                    empty ? '—' : value,
                    textAlign: TextAlign.end,
                    style: emphasis
                        ? t.num(15.sp, color: t.text)
                        : TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: empty ? t.textFaint : t.text,
                            fontFeatures: FxTokens.tabular,
                            height: 1.35,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter track (horizontally scrolling segmented pills) ──────────────────

class VmFilterItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? dot;
  const VmFilterItem(this.value, this.label, {this.icon, this.dot});
}

/// Same look as [FxSegmented], but content-sized and scrollable, for more than ~4 options.
/// The selected pill shows [count] when it is not null.
class VmFilterTrack<T> extends StatelessWidget {
  final List<VmFilterItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final int? count;

  const VmFilterTrack({super.key, required this.items, required this.value, required this.onChanged, this.count});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: t.dark ? const Color(0xFF0F172A) : const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (final it in items)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(it.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: it.value == value ? t.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(9.r),
                      boxShadow: it.value == value
                          ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))]
                          : const [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (it.icon != null) ...[
                          Icon(it.icon, size: 14.sp, color: it.value == value ? t.text : t.textMuted),
                          SizedBox(width: 5.w),
                        ] else if (it.dot != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: t.ink(it.dot!), shape: BoxShape.circle),
                          ),
                          SizedBox(width: 6.w),
                        ],
                        Text(
                          it.label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: it.value == value ? FontWeight.w700 : FontWeight.w500,
                            color: it.value == value ? t.text : t.textMuted,
                          ),
                        ),
                        if (it.value == value && count != null) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(color: t.soft(FxTokens.blue), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: t.ink(FxTokens.blue),
                                fontFeatures: FxTokens.tabular,
                              ),
                            ),
                          ),
                        ],
                      ],
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

// ─── Workflow steps ─────────────────────────────────────────────────────────

/// Compact 4-step progress of a maintenance ticket: Tạo phiếu → Kiểm tra → Phê duyệt → Đã duyệt.
/// Purely derived from the status (draft / submitted / reviewing / approved / completed).
class VmWorkflowSteps extends StatelessWidget {
  final String? status;

  const VmWorkflowSteps({super.key, required this.status});

  static const _labels = ['Tạo phiếu', 'Kiểm tra', 'Phê duyệt', 'Đã duyệt'];

  int get _current {
    switch (status) {
      case 'submitted':
        return 1;
      case 'reviewing':
        return 2;
      case 'approved':
      case 'completed':
        return 4; // all done
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final cur = _current;
    Widget dot(int i) {
      final done = i < cur;
      final active = i == cur;
      final c = done ? FxTokens.emerald : (active ? FxTokens.blue : t.textFaint);
      return Container(
        width: 22.w,
        height: 22.w,
        decoration: BoxDecoration(
          color: done ? FxTokens.emerald : (active ? t.soft(FxTokens.blue) : t.card),
          shape: BoxShape.circle,
          border: Border.all(color: done ? FxTokens.emerald : (active ? FxTokens.blue : t.border), width: 1.6),
        ),
        child: Center(
          child: done
              ? Icon(Icons.check_rounded, size: 13.sp, color: Colors.white)
              : Text('${i + 1}',
                  style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w800, color: active ? t.ink(FxTokens.blue) : c)),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              dot(i),
              if (i < _labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: i < cur ? FxTokens.emerald : t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: Text(
                  _labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: i == 0 ? TextAlign.start : (i == _labels.length - 1 ? TextAlign.end : TextAlign.center),
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                    color: i < cur ? t.ink(FxTokens.emerald) : (i == cur ? t.ink(FxTokens.blue) : t.textFaint),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Misc ───────────────────────────────────────────────────────────────────

/// Card that a loading dialog shows (spinner on the v2 card surface).
class VmLoadingCard extends StatelessWidget {
  const VmLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Center(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(FxTokens.rTile),
          border: Border.all(color: t.border),
        ),
        child: SizedBox(width: 28.w, height: 28.w, child: const CircularProgressIndicator(strokeWidth: 2.6)),
      ),
    );
  }
}

/// Title row for v2 dialogs: tinted icon badge + title.
class VmDialogTitle extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;

  const VmDialogTitle({super.key, required this.icon, required this.tone, required this.title});

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
