import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Card showing the selected vehicle; tapping opens a searchable, grouped vehicle list.
class FxVehicleHeader extends StatelessWidget {
  final List<FleetVehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final String emptyText;
  final Widget? trailing;

  const FxVehicleHeader({
    super.key,
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
    this.emptyText = 'Không có xe',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final cur = vehicles.where((v) => v.fleetVehicleId == selectedId).firstOrNull;
    return FxCard(
      padding: EdgeInsets.all(12.w),
      onTap: vehicles.isEmpty ? null : () => _open(context),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [FxTokens.blue, FxTokens.indigo], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: cur == null
                ? Text(vehicles.isEmpty ? emptyText : 'Chọn xe', style: t.h3.copyWith(color: t.textMuted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cur.displayName, style: t.h2.copyWith(fontSize: 16.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Flexible(child: Text(cur.plate, style: t.small.copyWith(fontFeatures: FxTokens.tabular))),
                          if (cur.type != null) ...[
                            Text('  ·  ', style: t.small),
                            Flexible(child: Text(cur.type!, style: t.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
          if (trailing != null) ...[trailing!, SizedBox(width: 6.w)],
          if (vehicles.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(color: t.soft(FxTokens.blue), borderRadius: BorderRadius.circular(10.r)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 15.sp, color: t.ink(FxTokens.blue)),
                  SizedBox(width: 4.w),
                  Text('Đổi xe', style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: t.ink(FxTokens.blue))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    final t = FxTokens.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: t.card,
      builder: (_) => _PickerSheet(
        vehicles: vehicles,
        selectedId: selectedId,
        onPick: (id) {
          Navigator.of(context).pop();
          onChanged(id);
        },
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final List<FleetVehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onPick;
  const _PickerSheet({required this.vehicles, required this.selectedId, required this.onPick});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final ql = _q.trim().toLowerCase();
    final list = widget.vehicles.where((v) => '${v.naName ?? ''} ${v.code} ${v.plate}'.toLowerCase().contains(ql)).toList()
      ..sort((a, b) {
        final c = (a.type ?? '').compareTo(b.type ?? '');
        return c != 0 ? c : fxNaturalCompare(a.displayName, b.displayName);
      });
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
            child: Row(
              children: [
                Text('Chọn xe', style: t.h1.copyWith(fontSize: 19.sp)),
                const Spacer(),
                Text('${list.length} xe', style: t.small),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
            child: FxSearchField(hint: 'Tìm theo tên xe, biển số…', onChanged: (v) => setState(() => _q = v)),
          ),
          Expanded(
            child: list.isEmpty
                ? const FxEmpty(icon: Icons.search_off_rounded, title: 'Không tìm thấy xe')
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 20.h),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final v = list[i];
                      final header = i == 0 || (list[i - 1].type ?? '') != (v.type ?? '');
                      final sel = v.fleetVehicleId == widget.selectedId;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (header)
                            Padding(
                              padding: EdgeInsets.fromLTRB(6.w, 14.h, 6.w, 6.h),
                              child: Text((v.type ?? 'Khác').toUpperCase(), style: t.overline),
                            ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Material(
                              color: sel ? t.soft(FxTokens.blue) : t.cardAlt,
                              borderRadius: BorderRadius.circular(12.r),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.r),
                                onTap: () => widget.onPick(v.fleetVehicleId),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: sel ? FxTokens.blue.withValues(alpha: 0.5) : t.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(v.concreteEnabled ? Icons.blender_outlined : Icons.local_shipping_outlined,
                                          size: 18.sp, color: sel ? t.ink(FxTokens.blue) : t.textMuted),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(v.displayName, style: t.h3),
                                            Text(v.plate, style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                                          ],
                                        ),
                                      ),
                                      if (v.concreteEnabled) const FxPill(label: 'Xe bồn', tone: FxTokens.cyan),
                                      if (sel) ...[
                                        SizedBox(width: 8.w),
                                        Icon(Icons.check_circle_rounded, size: 20.sp, color: FxTokens.blue),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
int fxNaturalCompare(String a, String b) {
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
