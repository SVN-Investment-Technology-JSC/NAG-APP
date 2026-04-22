import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';

class VehicleChipsBar extends StatelessWidget {
  final List<VehicleModel> vehicles;
  final int? selectedVehicleId;
  final ValueChanged<int?> onVehicleSelected;
  final ColorScheme colorScheme;
  final bool isDark;

  const VehicleChipsBar({
    super.key,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.onVehicleSelected,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          final isSelected = vehicle.vehicleId == selectedVehicleId;

          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () {
                if (isSelected) {
                  onVehicleSelected(null);
                } else {
                  onVehicleSelected(vehicle.vehicleId);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.15 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 14.sp,
                      color: isSelected
                          ? Colors.white
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      vehicle.vehicleLicensePlate,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
