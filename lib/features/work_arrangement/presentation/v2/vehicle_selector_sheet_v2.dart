import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';

/// v2 of `VehicleSelectorSheet`: same constructor, same `show()`, same search rule and selection flow.
class VehicleSelectorSheetV2 extends StatefulWidget {
  final List<WorkVehicle> availableVehicles;
  final Function(WorkVehicle) onSelected;

  const VehicleSelectorSheetV2({super.key, required this.availableVehicles, required this.onSelected});

  static Future<void> show(BuildContext context, List<WorkVehicle> vehicles, Function(WorkVehicle) onSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FxTokens.of(context).card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => VehicleSelectorSheetV2(availableVehicles: vehicles, onSelected: onSelected),
    );
  }

  @override
  State<VehicleSelectorSheetV2> createState() => _VehicleSelectorSheetV2State();
}

class _VehicleSelectorSheetV2State extends State<VehicleSelectorSheetV2> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    // Same filter as v1
    final filtered = widget.availableVehicles.where((v) {
      final name = v.vehicleName?.toLowerCase() ?? '';
      final plate = v.vehicleLicensePlate?.toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || plate.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WaSheetHandle(),
            WaSheetHeader(
              icon: Icons.local_shipping_rounded,
              tone: FxTokens.blue,
              title: 'Chọn xe trống',
              subtitle: '${widget.availableVehicles.length} xe chưa được bố trí',
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: FxSearchField(
                hint: 'Tìm kiếm biển số hoặc tên xe...',
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            SizedBox(height: 12.h),
            Divider(height: 1, color: t.divider),
            Expanded(
              child: filtered.isEmpty
                  ? ListView(
                      controller: scrollController,
                      children: [
                        SizedBox(height: 24.h),
                        const FxEmpty(icon: Icons.local_shipping_outlined, title: 'Không có xe trống nào'),
                      ],
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 16.h),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final v = filtered[index];
                        return WaVehicleRow(
                          plate: v.vehicleLicensePlate ?? '',
                          name: v.vehicleName,
                          type: v.vehicleTypeName,
                          trailing: Icon(Icons.add_circle_outline_rounded, size: 20.sp, color: t.ink(FxTokens.blue)),
                          onTap: () {
                            widget.onSelected(v);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
