import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';

/// Presentation helpers shared by the v2 "Quản lý người dùng" screens (no logic here).

/// Accent colour of a role (avatar, role pill, role selector).
Color umRoleTone(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return FxTokens.violet;
    case 'manager':
      return FxTokens.blue;
    case 'dispatcher':
      return FxTokens.amber;
    case 'driver':
      return FxTokens.emerald;
    case 'user':
      return FxTokens.slate;
    default:
      return FxTokens.cyan;
  }
}

IconData umRoleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return Icons.admin_panel_settings_rounded;
    case 'manager':
      return Icons.supervisor_account_rounded;
    case 'dispatcher':
      return Icons.support_agent_rounded;
    case 'driver':
      return Icons.local_shipping_rounded;
    case 'user':
      return Icons.person_rounded;
    default:
      return Icons.badge_rounded;
  }
}

/// Display label + tone of a `user_status` value (null when there is nothing to show).
({String label, Color tone})? umStatus(String? status) {
  final raw = status?.trim() ?? '';
  if (raw.isEmpty) return null;
  final s = raw.toLowerCase();
  const active = {'active', '1', 'true', 'enabled', 'working', 'hoạt động', 'đang làm việc'};
  const inactive = {'inactive', '0', 'false', 'disabled', 'resigned', 'quit', 'nghỉ việc', 'ngừng hoạt động'};
  const locked = {'locked', 'blocked', 'banned', 'suspended', 'đã khoá', 'đã khóa'};
  if (active.contains(s)) return (label: 'Hoạt động', tone: FxTokens.emerald);
  if (inactive.contains(s)) return (label: 'Ngừng hoạt động', tone: FxTokens.slate);
  if (locked.contains(s)) return (label: 'Đã khoá', tone: FxTokens.red);
  return (label: raw, tone: FxTokens.slate);
}

/// "Nguyễn Văn An" → "NA".
String umInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

/// Round initials avatar tinted with a tone.
class UmAvatar extends StatelessWidget {
  final String name;
  final Color tone;
  final double size;

  const UmAvatar({super.key, required this.name, required this.tone, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final initials = umInitials(name);
    final d = size.w;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.soft(tone),
        border: Border.all(color: tone.withValues(alpha: t.dark ? 0.35 : 0.22)),
      ),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: d * 0.5, color: t.ink(tone))
          : Text(
              initials,
              style: TextStyle(fontSize: d * 0.36, fontWeight: FontWeight.w800, color: t.ink(tone), letterSpacing: 0.2),
            ),
    );
  }
}

/// Selectable filter chip (role filter, category filter).
class UmFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color tone;
  final String? count;

  const UmFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tone = FxTokens.blue,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fg = selected ? t.ink(tone) : t.textMuted;
    return Material(
      color: selected ? t.soft(tone) : t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: selected ? tone.withValues(alpha: 0.45) : t.border, width: selected ? 1.3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14.sp, color: fg),
                SizedBox(width: 5.w),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(fontSize: 12.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: fg),
              ),
              if (count != null) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: selected ? tone : t.cardAlt,
                    borderRadius: BorderRadius.circular(8.r),
                    border: selected ? null : Border.all(color: t.border),
                  ),
                  child: Text(
                    count!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : t.textMuted,
                      fontFeatures: FxTokens.tabular,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped block inside a form sheet: small header + fields.
class UmFormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color tone;
  final List<Widget> children;

  const UmFormSection({super.key, required this.icon, required this.title, this.tone = FxTokens.blue, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(height: 12.h));
      items.add(children[i]);
    }
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: t.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UmIconSquare(icon: icon, tone: tone),
              SizedBox(width: 8.w),
              Expanded(child: Text(title.toUpperCase(), style: t.overline.copyWith(color: t.textMuted))),
            ],
          ),
          SizedBox(height: 12.h),
          ...items,
        ],
      ),
    );
  }
}

/// 24-px tinted icon square (section headers).
class UmIconSquare extends StatelessWidget {
  final IconData icon;
  final Color tone;

  const UmIconSquare({super.key, required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(color: t.soft(tone), borderRadius: BorderRadius.circular(7.r)),
      child: Icon(icon, size: 14.sp, color: t.ink(tone)),
    );
  }
}

/// Text-field decoration in the v2 style (token colours, works in light and dark).
InputDecoration umInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? helper,
  Widget? suffix,
  bool enabled = true,
}) {
  final t = FxTokens.of(context);
  final cs = Theme.of(context).colorScheme;
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    helperStyle: t.tiny,
    labelStyle: TextStyle(color: t.textMuted, fontSize: 13.sp),
    floatingLabelStyle: TextStyle(color: t.ink(FxTokens.blue), fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, size: 19.sp, color: enabled ? t.textMuted : t.textFaint),
    suffixIcon: suffix,
    filled: true,
    fillColor: enabled ? t.cardAlt : t.divider,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
    border: b(t.border),
    enabledBorder: b(t.border),
    disabledBorder: b(t.border.withValues(alpha: 0.6)),
    focusedBorder: b(FxTokens.blue, 1.5),
    errorBorder: b(cs.error),
    focusedErrorBorder: b(cs.error, 1.5),
  );
}
