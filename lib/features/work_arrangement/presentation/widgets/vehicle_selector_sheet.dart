import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class VehicleSelectorSheet extends StatefulWidget {
  final List<WorkVehicle> availableVehicles;
  final Function(WorkVehicle) onSelected;

  const VehicleSelectorSheet({
    super.key,
    required this.availableVehicles,
    required this.onSelected,
  });

  static Future<void> show(BuildContext context, List<WorkVehicle> vehicles, Function(WorkVehicle) onSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => VehicleSelectorSheet(availableVehicles: vehicles, onSelected: onSelected),
    );
  }

  @override
  State<VehicleSelectorSheet> createState() => _VehicleSelectorSheetState();
}

class _VehicleSelectorSheetState extends State<VehicleSelectorSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Text('Chọn xe trống', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  CloseButton(onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm biển số hoặc tên xe...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            SizedBox(height: 12.h),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('Không có xe trống nào', style: theme.textTheme.bodyLarge))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final v = filtered[index];
                        return ListTile(
                          leading: Icon(Icons.local_shipping, color: colorScheme.primary),
                          title: Text(v.vehicleLicensePlate ?? ''),
                          subtitle: Text(v.vehicleName ?? ''),
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
