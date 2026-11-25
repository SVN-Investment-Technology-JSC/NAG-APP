import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// Building blocks of the v2 "Chuyến đi" screen (queue cards, trip timeline, vehicle tiles).

// ─── Small pieces ───────────────────────────────────────────────────────────

/// Icon + text metadata chip (tinted when [tone] is given).
class VxMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tone;

  const VxMetaChip({super.key, required this.icon, required this.label, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final fg = tone == null ? t.textMuted : t.ink(tone!);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: tone == null ? t.cardAlt : t.soft(tone!),
        borderRadius: BorderRadius.circular(8.r),
        border: tone == null ? Border.all(color: t.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: fg),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: fg,
                fontFeatures: FxTokens.tabular,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Queue (lot order) card ─────────────────────────────────────────────────

/// v2 of `HomeOrderItem` for the vehicle queue: same fields and same status rules, new layout.
class VxQueueOrderCard extends StatelessWidget {
  final OrderModel order;
  final int orderNumber;
  final List<VehicleModel> vehicles;
  final bool manual;

  const VxQueueOrderCard({
    super.key,
    required this.order,
    required this.orderNumber,
    required this.vehicles,
    this.manual = false,
  });

  String get _vehicleLabel {
    final plate = order.vehicles?.vehicleLicensePlate ?? '---';
    final vehicleName = vehicles
        .where((v) => v.vehicleId == order.vehicles?.vehicleId)
        .map((v) => v.vehicleName)
        .firstOrNull;
    if (vehicleName != null && vehicleName.isNotEmpty) {
      return '$plate | $vehicleName';
    }
    return plate;
  }

  ({Color tone, String text}) _resolveStatus(AppLocalizations l10n) {
    switch (order.orderStatus) {
      case 'completed':
        return (tone: FxTokens.emerald, text: l10n.completedStatus);
      case 'collecting':
        return (tone: FxTokens.amber, text: l10n.collecting);
      case 'init':
        return (tone: FxTokens.slate, text: l10n.initStatus);
      default:
        return (tone: FxTokens.blue, text: l10n.pendingOrders);
    }
  }

  String? _computeInitTime(AppLocalizations l10n) {
    final initDt = DateTime.tryParse(order.orderInitDatetime);
    if (initDt == null) return null;
    final local = initDt.toLocal();
    return '${local.hour} ${l10n.hours} ${local.minute.toString().padLeft(2, '0')} ${l10n.minutes}';
  }

  String? _computeDuration(AppLocalizations l10n) {
    if (order.orderStartDatetime == null || order.orderEndDatetime == null) {
      return null;
    }
    final start = DateTime.tryParse(order.orderStartDatetime!);
    final end = DateTime.tryParse(order.orderEndDatetime!);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return hours > 0
        ? '$hours${l10n.hours[0]}${mins.toString().padLeft(2, '0')}${l10n.minutes[0]}'
        : '$mins${l10n.minutes[0]}';
  }

  String? _computeEndTime() {
    if (order.orderEndDatetime == null) return null;
    final end = DateTime.tryParse(order.orderEndDatetime!);
    if (end == null) return null;
    return DateFormat('HH:mm').format(end.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final status = _resolveStatus(l10n);
    final initTime = _computeInitTime(l10n);
    final duration = _computeDuration(l10n);
    final endTime = _computeEndTime();
    final multi = order.orderStatus == 'completed' ? order.orderMulti : null;
    final lead = orderNumber == 1;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800.w),
        child: Container(
          margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
          padding: EdgeInsets.fromLTRB(12.w, 12.h, manual ? 6.w : 12.w, 12.h),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(FxTokens.rTile),
            border: Border.all(
              color: order.orderStatus == 'collecting'
                  ? status.tone.withValues(alpha: 0.45)
                  : t.border.withValues(alpha: 0.8),
              width: order.orderStatus == 'collecting' ? 1.4 : 1,
            ),
            boxShadow: t.shadow,
          ),
          child: Row(
            children: [
              // Position in the queue
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: lead
                      ? const LinearGradient(
                          colors: [FxTokens.blue, FxTokens.indigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: lead ? null : t.soft(status.tone),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      '#$orderNumber',
                      style: t.num(15.sp, color: lead ? Colors.white : t.ink(status.tone)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _vehicleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.h3.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Flexible(child: FxPill(label: status.text, tone: status.tone, dot: true)),
                      ],
                    ),
                    if (initTime != null || duration != null || endTime != null) ...[
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 4.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (initTime != null) _meta(t, Icons.access_time_rounded, initTime, null),
                          if (duration != null) _meta(t, Icons.schedule_rounded, duration, status.tone),
                          if (endTime != null) _meta(t, Icons.flag_outlined, endTime, null),
                        ],
                      ),
                    ],
                    if (multi != null) ...[
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [
                          VxMetaChip(icon: Icons.straighten_rounded, label: '${multi.distanceKm.toStringAsFixed(1)} km'),
                          VxMetaChip(
                            icon: Icons.pause_circle_outline_rounded,
                            label: '${multi.stopCount} ${l10n.stopCountLabel}',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (manual) ...[
                SizedBox(width: 4.w),
                Icon(Icons.drag_indicator_rounded, size: 22.sp, color: t.textFaint),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(FxTokens t, IconData icon, String text, Color? tone) {
    final c = tone == null ? t.textMuted : t.ink(tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: c),
        SizedBox(width: 3.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: c,
            fontFeatures: FxTokens.tabular,
          ),
        ),
      ],
    );
  }
}

// ─── Trip (order) of a vehicle on the selected day ──────────────────────────

/// Timeline row for one trip in the vehicle sheet. Same texts and status rules as the original `_tripItem`.
class VxTripTimelineItem extends StatelessWidget {
  final OrderModel order;
  final bool isLast;

  const VxTripTimelineItem({super.key, required this.order, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    final isCompleted = order.orderStatus == 'completed';
    final isActive = order.orderStatus == 'collecting' ||
        order.orderStatus == 'transporting' ||
        order.orderStatus == 'running';

    Color accentColor;
    String statusText;
    if (isCompleted) {
      accentColor = FxTokens.emerald;
      statusText = l10n.completedStatus;
    } else if (isActive) {
      accentColor = FxTokens.cyan;
      statusText = l10n.transportingStatus;
    } else if (order.orderStatus == 'collecting') {
      accentColor = FxTokens.amber;
      statusText = l10n.collecting;
    } else if (order.orderStatus == 'init') {
      accentColor = FxTokens.slate;
      statusText = l10n.initStatus;
    } else {
      accentColor = FxTokens.blue;
      statusText = l10n.pendingOrders;
    }

    // Init time
    String? initTimeText;
    final initDt = DateTime.tryParse(order.orderInitDatetime);
    if (initDt != null) {
      final local = initDt.toLocal();
      initTimeText = '${local.hour} ${l10n.hours} ${local.minute.toString().padLeft(2, '0')} ${l10n.minutes}';
    }

    // Start → End time
    String? startTimeText;
    if (order.orderStartDatetime != null) {
      final dt = DateTime.tryParse(order.orderStartDatetime!);
      if (dt != null) startTimeText = DateFormat('HH:mm').format(dt.toLocal());
    }
    String? endTimeText;
    if (order.orderEndDatetime != null) {
      final dt = DateTime.tryParse(order.orderEndDatetime!);
      if (dt != null) endTimeText = DateFormat('HH:mm').format(dt.toLocal());
    }

    // Running duration
    String? runDurationText;
    if (order.orderStartDatetime != null && order.orderEndDatetime != null) {
      final start = DateTime.tryParse(order.orderStartDatetime!);
      final end = DateTime.tryParse(order.orderEndDatetime!);
      if (start != null && end != null) {
        final diffMins = end.difference(start).inMinutes;
        final h = diffMins ~/ 60;
        final m = diffMins % 60;
        runDurationText = h > 0 ? '$h ${l10n.hours} $m ${l10n.minutes}' : '$m ${l10n.minutes}';
      }
    }

    // Mixing duration
    String? mixDurationText;
    final mixInVal = order.orderMulti?.checkinTimeStation ?? order.checkinTimeStation;
    final mixOutVal = order.orderMulti?.checkoutTimeStation ?? order.checkoutTimeStation;
    if (mixInVal != null && mixOutVal != null) {
      final mixIn = DateTime.tryParse(mixInVal);
      final mixOut = DateTime.tryParse(mixOutVal);
      if (mixIn != null && mixOut != null) {
        final mixMins = mixOut.difference(mixIn).inMinutes;
        if (mixMins > 0) {
          final h = mixMins ~/ 60;
          final m = mixMins % 60;
          mixDurationText = h > 0 ? '$h ${l10n.hours} $m ${l10n.minutes}' : '$mixMins ${l10n.minutes}';
        }
      }
    }

    // Distance & stops
    final multi = order.orderMulti;
    String? distanceText;
    String? stopsText;
    if (multi != null) {
      if (multi.distanceKm > 0) distanceText = '${multi.distanceKm.toStringAsFixed(1)} km';
      if (multi.stopCount > 0) {
        if (multi.stopDurationSeconds > 0) {
          final stopMins = multi.stopDurationSeconds ~/ 60;
          stopsText = '${multi.stopCount} ${l10n.stopCountLabel} ($stopMins ${l10n.minutes})';
        } else {
          stopsText = '${multi.stopCount} ${l10n.stopCountLabel}';
        }
      }
    }

    final running = startTimeText != null && endTimeText == null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail
          SizedBox(
            width: 16.w,
            child: Column(
              children: [
                SizedBox(height: 16.h),
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.card, width: 2.5),
                    boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.35), blurRadius: 6)],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, margin: EdgeInsets.only(top: 3.h), color: t.border),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: t.cardAlt,
                borderRadius: BorderRadius.circular(FxTokens.rTile),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station + status
                  Row(
                    children: [
                      Icon(Icons.factory_rounded, size: 14.sp, color: t.ink(accentColor)),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          order.stations?.stationName ?? '---',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.h3,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Flexible(child: FxPill(label: statusText, tone: accentColor, dot: true)),
                    ],
                  ),
                  if (initTimeText != null) ...[
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11.sp, color: t.textFaint),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            initTimeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Start → End + running duration
                  if (startTimeText != null || runDurationText != null) ...[
                    SizedBox(height: 10.h),
                    _timeStrip(t, accentColor, startTimeText, endTimeText, runDurationText, running),
                  ],
                  // Mixing duration + distance + stops
                  if (mixDurationText != null || distanceText != null || stopsText != null) ...[
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        if (mixDurationText != null)
                          VxMetaChip(
                            icon: Icons.blender_rounded,
                            label: '${l10n.mixLabel}: $mixDurationText',
                            tone: FxTokens.violet,
                          ),
                        if (distanceText != null) VxMetaChip(icon: Icons.straighten_rounded, label: distanceText),
                        if (stopsText != null) VxMetaChip(icon: Icons.pause_circle_outline_rounded, label: stopsText),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeStrip(FxTokens t, Color tone, String? start, String? end, String? duration, bool running) {
    Widget node(bool filled) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: filled ? tone : t.card,
            shape: BoxShape.circle,
            border: Border.all(color: tone, width: 2),
          ),
        );

    return Row(
      children: [
        if (start != null) ...[
          Icon(Icons.play_circle_outline_rounded, size: 14.sp, color: t.ink(FxTokens.cyan)),
          SizedBox(width: 4.w),
          Text(start, style: t.num(15.sp)),
          SizedBox(width: 8.w),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (duration != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 11.sp, color: t.ink(FxTokens.amber)),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          duration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: t.ink(FxTokens.amber),
                            fontFeatures: FxTokens.tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  node(true),
                  Expanded(
                    child: running
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: tone,
                              backgroundColor: t.soft(tone),
                            ),
                          )
                        : Container(height: 2, color: tone.withValues(alpha: 0.55)),
                  ),
                  node(!running),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        if (start != null)
          if (end != null)
            Text(end, style: t.num(15.sp))
          else
            SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: t.ink(FxTokens.cyan)),
            ),
      ],
    );
  }
}

// ─── Vehicle tile of the daily trips list ───────────────────────────────────

class VxVehicleTile extends StatelessWidget {
  final VehicleModel vehicle;
  final int index;
  final int tripCount;
  final VoidCallback onTap;

  const VxVehicleTile({
    super.key,
    required this.vehicle,
    required this.index,
    required this.tripCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isMixer = vehicle.vehicleName.toUpperCase().startsWith('X');
    final tone = isMixer ? FxTokens.blue : FxTokens.cyan;
    final hasTrips = tripCount > 0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800.w),
        child: Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Material(
            color: t.card,
            borderRadius: BorderRadius.circular(FxTokens.rTile),
            child: InkWell(
              borderRadius: BorderRadius.circular(FxTokens.rTile),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.fromLTRB(12.w, 11.h, 8.w, 11.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FxTokens.rTile),
                  border: Border.all(color: t.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    FxIconBadge(
                      icon: isMixer ? Icons.local_shipping_rounded : Icons.airport_shuttle_rounded,
                      tone: tone,
                      size: 40,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.vehicleName.isNotEmpty ? vehicle.vehicleName : '#${index + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.h3.copyWith(fontSize: 14.sp, color: t.ink(tone), fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            vehicle.vehicleLicensePlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.small.copyWith(
                              color: t.text,
                              fontWeight: FontWeight.w600,
                              fontFeatures: FxTokens.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    if (hasTrips)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: t.soft(tone),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$tripCount', style: t.num(16.sp, color: t.ink(tone))),
                            SizedBox(width: 4.w),
                            Text(
                              l10n.trips,
                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: t.ink(tone)),
                            ),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 120.w),
                        child: Text(
                          l10n.noTripsYet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.tiny.copyWith(color: t.textFaint, fontStyle: FontStyle.italic),
                        ),
                      ),
                    SizedBox(width: 4.w),
                    Icon(Icons.chevron_right_rounded, size: 20.sp, color: t.textFaint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
