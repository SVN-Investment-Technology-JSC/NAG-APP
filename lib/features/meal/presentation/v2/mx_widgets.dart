import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';

/// Building blocks of the v2 "Cơm ca" screen (slot toggles, avatars, grouped card segments).

/// Short label of a meal slot key, same mapping as v1 ('sang' → Tr, 'trua' → Ch, else T).
String mxSlotShort(String? slot) => slot == 'sang' ? 'Tr' : slot == 'trua' ? 'Ch' : 'T';

/// Card made of stacked slivers: a [top] piece, middle pieces and a [bottom] piece share one hairline
/// outline, so a lazily built list still reads as a single card.
class MxSegment extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final VoidCallback? onTap;

  const MxSegment({super.key, required this.child, this.top = false, this.bottom = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final r = Radius.circular(16.r);
    final ri = Radius.circular(15.r);
    return Container(
      margin: EdgeInsets.only(bottom: bottom ? 10.h : 0),
      padding: EdgeInsets.fromLTRB(1, top ? 1 : 0, 1, bottom ? 1 : 0),
      decoration: BoxDecoration(
        color: t.border.withValues(alpha: 0.85),
        borderRadius: BorderRadius.vertical(top: top ? r : Radius.zero, bottom: bottom ? r : Radius.zero),
      ),
      child: Material(
        color: t.card,
        borderRadius: BorderRadius.vertical(top: top ? ri : Radius.zero, bottom: bottom ? ri : Radius.zero),
        clipBehavior: top || bottom ? Clip.antiAlias : Clip.none,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Round initial avatar.
class MxAvatar extends StatelessWidget {
  final String name;
  final Color tone;
  final double size;

  const MxAvatar({super.key, required this.name, required this.tone, this.size = 34});

  static String initialOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.last.characters.first.toUpperCase();
  }

  static const _palette = [
    FxTokens.blue,
    FxTokens.indigo,
    FxTokens.emerald,
    FxTokens.violet,
    FxTokens.cyan,
    FxTokens.amber,
    FxTokens.orange,
  ];

  /// Stable tone for a name.
  static Color toneFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft(tone), shape: BoxShape.circle),
      child: Text(
        initialOf(name),
        style: TextStyle(fontSize: (size * 0.4).sp, fontWeight: FontWeight.w800, color: t.ink(tone), height: 1),
      ),
    );
  }
}

/// Tappable meal-slot cell (Tr / Ch / T): green when counted automatically, amber when marked by hand,
/// outlined when empty; a blue dot marks an unsaved change.
class MxSlotToggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool manual;
  final bool pending;
  final VoidCallback? onTap;
  final double size;

  const MxSlotToggle({
    super.key,
    required this.label,
    required this.active,
    this.manual = false,
    this.pending = false,
    this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final tone = manual ? FxTokens.amber : FxTokens.emerald;
    final bg = active ? t.soft(tone) : Colors.transparent;
    final borderColor = active ? tone.withValues(alpha: manual ? 0.7 : 0.45) : t.border;
    final fg = active ? t.ink(tone) : t.textFaint;
    final s = size.w;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: bg,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(s * 0.3),
                side: BorderSide(color: borderColor, width: active && manual ? 1.4 : 1),
              ),
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: (size * 0.33).sp, fontWeight: FontWeight.w800, color: fg, height: 1),
                  ),
                ),
              ),
            ),
          ),
          if (pending)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: FxTokens.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.card, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small read-only slot chip (day detail sheet): green = automatic, amber = by hand.
class MxSlotChip extends StatelessWidget {
  final String label;
  final bool manual;

  const MxSlotChip({super.key, required this.label, required this.manual});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final tone = manual ? FxTokens.amber : FxTokens.emerald;
    return Container(
      constraints: BoxConstraints(minWidth: 28.w),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: t.soft(tone),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: tone.withValues(alpha: manual ? 0.6 : 0.35)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w800, color: t.ink(tone), height: 1.1),
      ),
    );
  }
}

/// Square bordered icon button (date navigation, toolbars).
class MxSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  const MxSquareButton({super.key, required this.icon, this.onTap, this.tooltip, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final btn = Material(
      color: t.cardAlt,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: t.border)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: Icon(icon, size: 20.sp, color: onTap == null ? t.textFaint : t.text),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
