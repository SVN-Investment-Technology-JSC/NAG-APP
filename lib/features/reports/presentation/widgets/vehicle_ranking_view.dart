import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class VehicleRankingView extends StatelessWidget {
  final ProductionReportResponse? report;

  const VehicleRankingView({super.key, this.report});

  @override
  Widget build(BuildContext context) {
    if (report == null || report!.topVehicles.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(child: Text(l10n.noData));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final vehicles = report!.topVehicles;

    return Column(
      children: [
        // Header info
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.emoji_events_outlined, color: Colors.blue, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.vehicleRankingTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l10n.vehicleRankingDesc,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                SizedBox(width: 30.w, child: Text('#', style: _headerStyle(theme))),
                SizedBox(width: 60.w, child: Text(l10n.vehicleCode, style: _headerStyle(theme))),
                Expanded(child: Text(l10n.licensePlate, style: _headerStyle(theme))),
                SizedBox(width: 8.w),
                SizedBox(width: 70.w, child: Text(l10n.tripsUpper, style: _headerStyle(theme))),
                SizedBox(width: 50.w, child: Text('KM', style: _headerStyle(theme), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ),

        // Vehicle List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              final rank = index + 1;
              final isTop3 = rank <= 3;
              final isRank45 = rank == 4 || rank == 5;
              final isBottom3 = rank > vehicles.length - 3 && rank > 3 && !isRank45;

              Color? rowColor;
              Color circleColor;
              Color highlightColor;

              if (isTop3) {
                rowColor = Colors.blue.withValues(alpha: 0.03);
                circleColor = Colors.blue.withValues(alpha: 0.1);
                highlightColor = Colors.blue;
              } else if (isRank45) {
                rowColor = Colors.green.withValues(alpha: 0.03);
                circleColor = Colors.green.withValues(alpha: 0.1);
                highlightColor = Colors.green;
              } else if (isBottom3) {
                rowColor = Colors.red.withValues(alpha: 0.03);
                circleColor = Colors.red.withValues(alpha: 0.1);
                highlightColor = Colors.red;
              } else {
                rowColor = null;
                circleColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
                highlightColor = colorScheme.onSurfaceVariant;
              }

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: rowColor,
                  border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30.w,
                      child: Container(
                        width: 24.w,
                        height: 24.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: highlightColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60.w,
                      child: Text(
                        vehicle.vehicleName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isTop3 || isRank45 || isBottom3 ? highlightColor : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            vehicle.vehicleLicensePlate,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    SizedBox(
                      width: 70.w,
                      child: Text(
                        '${vehicle.totalOrders} ${l10n.trips}',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(
                      width: 50.w,
                      child: Text(
                        vehicle.totalDistanceKm.round().toLocaleString(),
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  TextStyle? _headerStyle(ThemeData theme) {
    return theme.textTheme.labelSmall?.copyWith(
      fontSize: 10.sp,
      fontWeight: FontWeight.w900,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );
  }
}

extension on num {
  String toLocaleString() {
    return NumberFormat('#,###').format(this);
  }
}
