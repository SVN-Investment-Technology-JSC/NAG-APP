import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';

/// Rounded white card with an optional title, used for every block of the fleet pages.
class FleetSection extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const FleetSection({super.key, this.title, this.trailing, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: padding ?? EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: 8.h),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small coloured pill (status / severity / risk).
class ToneChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dense;

  const ToneChip({super.key, required this.label, required this.color, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6.w : 8.w, vertical: dense ? 1.h : 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: dense ? 10.sp : 11.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// KPI tile: icon + label + big value (+ optional sub line and badge).
class KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Widget? badge;
  final Color color;
  final String? hint;

  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.badge,
    required this.color,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tile = Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8.r)),
                child: Icon(icon, size: 15.sp, color: color),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant, height: 1.2),
                ),
              ),
              if (hint != null) Icon(Icons.info_outline_rounded, size: 13.sp, color: cs.onSurfaceVariant),
            ],
          ),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900)),
          ),
          if (sub != null) ...[
            SizedBox(height: 2.h),
            Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
          ],
          if (badge != null) ...[SizedBox(height: 4.h), badge!],
        ],
      ),
    );
    if (hint == null || hint!.isEmpty) return tile;
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(hint!), duration: const Duration(seconds: 4))),
      child: tile,
    );
  }
}

/// Two-column grid of KPI tiles.
class KpiGrid extends StatelessWidget {
  final List<Widget> children;
  const KpiGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : 2;
      final gap = 8.w;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((e) => SizedBox(width: w, child: e)).toList(),
        ),
      );
    });
  }
}

class FleetEmpty extends StatelessWidget {
  final String text;
  final IconData icon;
  const FleetEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      child: Column(
        children: [
          Icon(icon, size: 32.sp, color: cs.outline),
          SizedBox(height: 6.h),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class FleetNotice extends StatelessWidget {
  final String text;
  final Color color;
  const FleetNotice(this.text, {super.key, this.color = const Color(0xFFD97706)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12.sp, color: color, height: 1.35)),
    );
  }
}

/// Field that shows the selected vehicle and opens a searchable list.
class VehiclePickerField extends StatelessWidget {
  final List<FleetVehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final String emptyText;

  const VehiclePickerField({
    super.key,
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
    this.emptyText = 'Không có xe',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = vehicles.where((v) => v.fleetVehicleId == selectedId).firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: vehicles.isEmpty ? null : () => _open(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 18.sp, color: cs.primary),
            SizedBox(width: 8.w),
            Expanded(
              child: cur == null
                  ? Text(vehicles.isEmpty ? emptyText : 'Chọn xe', style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant))
                  : Text.rich(
                      TextSpan(children: [
                        TextSpan(text: cur.displayName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp)),
                        TextSpan(text: '  ·  ${cur.plate}', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _VehiclePickerSheet(vehicles: vehicles, selectedId: selectedId, onPick: (id) {
        Navigator.of(context).pop();
        onChanged(id);
      }),
    );
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<FleetVehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onPick;
  const _VehiclePickerSheet({required this.vehicles, required this.selectedId, required this.onPick});

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ql = _q.trim().toLowerCase();
    final list = widget.vehicles.where((v) => '${v.naName ?? ''} ${v.code} ${v.plate}'.toLowerCase().contains(ql)).toList()
      ..sort((a, b) {
        final t = (a.type ?? '').compareTo(b.type ?? '');
        return t != 0 ? t : _natural(a.displayName, b.displayName);
      });
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Tìm xe, biển số…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: list.isEmpty
                ? const FleetEmpty('Không có xe')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final v = list[i];
                      final header = i == 0 || (list[i - 1].type ?? '') != (v.type ?? '');
                      final sel = v.fleetVehicleId == widget.selectedId;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (header)
                            Padding(
                              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
                              child: Text(
                                (v.type ?? 'Khác').toUpperCase(),
                                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: cs.outline, letterSpacing: 0.6),
                              ),
                            ),
                          ListTile(
                            dense: true,
                            selected: sel,
                            selectedTileColor: cs.primary.withValues(alpha: 0.08),
                            title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(v.plate),
                            trailing: v.concreteEnabled ? Text('xe bồn', style: TextStyle(fontSize: 11.sp, color: cs.outline)) : null,
                            onTap: () => widget.onPick(v.fleetVehicleId),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Natural-ish compare so "X2" sorts before "X10".
int _natural(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final ma = re.allMatches(a).toList(), mb = re.allMatches(b).toList();
  for (var i = 0; i < ma.length && i < mb.length; i++) {
    final x = ma[i].group(0)!, y = mb[i].group(0)!;
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.toLowerCase().compareTo(y.toLowerCase());
    if (c != 0) return c;
  }
  return ma.length.compareTo(mb.length);
}

/// Horizontal row of choice chips.
class SegmentChips<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;

  const SegmentChips({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o.$2, style: TextStyle(fontSize: 12.sp)),
                selected: o.$1 == value,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(o.$1),
              ))
          .toList(),
    );
  }
}
