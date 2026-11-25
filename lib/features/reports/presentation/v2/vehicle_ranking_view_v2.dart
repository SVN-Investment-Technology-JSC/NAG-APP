import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Xếp hạng xe" (v2). Same data, order and highlight rules (top 3 / rank 4–5 / bottom 3) as v1;
/// shown as a podium plus a paginated ranking list.
class VehicleRankingViewV2 extends StatefulWidget {
  final ProductionReportResponse? report;

  const VehicleRankingViewV2({super.key, this.report});

  @override
  State<VehicleRankingViewV2> createState() => _VehicleRankingViewV2State();
}

class _VehicleRankingViewV2State extends State<VehicleRankingViewV2> {
  static const _perPage = 10;
  int _page = 0;

  @override
  void didUpdateWidget(VehicleRankingViewV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report) _page = 0;
  }

  /// Highlight colour of a rank (null = not highlighted) — same rules as v1.
  Color? _tierTone(int rank, int count) {
    final isTop3 = rank <= 3;
    final isRank45 = rank == 4 || rank == 5;
    final isBottom3 = rank > count - 3 && rank > 3 && !isRank45;
    if (isTop3) return FxTokens.blue;
    if (isRank45) return FxTokens.green;
    if (isBottom3) return FxTokens.red;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (widget.report == null || widget.report!.topVehicles.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(14.w),
        children: [
          SizedBox(height: 40.h),
          FxEmpty(icon: Icons.emoji_events_outlined, title: l10n.noData),
        ],
      );
    }

    final vehicles = widget.report!.topVehicles;
    final showPodium = vehicles.length >= 3;
    final listStart = showPodium ? 3 : 0;
    final rest = vehicles.sublist(listStart);
    final maxOrders = vehicles.map((v) => v.totalOrders).fold<int>(0, math.max);
    final page = fxPage(rest, _page, _perPage);
    final pages = math.max(1, (rest.length / _perPage).ceil());
    final offset = _page.clamp(0, pages - 1).toInt() * _perPage;

    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 28.h),
      children: [
        FxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FxSectionHeader(
                icon: Icons.emoji_events_outlined,
                title: l10n.vehicleRankingTitle,
                subtitle: l10n.vehicleRankingDesc,
                tone: FxTokens.amber,
                trailing: FxPill(label: '${vehicles.length} xe', tone: FxTokens.slate),
              ),
              if (showPodium) ...[
                SizedBox(height: 4.h),
                _podium(t, l10n, vehicles),
              ],
              SizedBox(height: 12.h),
              Wrap(
                spacing: 14.w,
                runSpacing: 6.h,
                children: const [
                  FxLegend(color: FxTokens.blue, label: 'Top 3'),
                  FxLegend(color: FxTokens.green, label: 'Hạng 4–5'),
                  FxLegend(color: FxTokens.red, label: '3 xe cuối'),
                ],
              ),
            ],
          ),
        ),
        if (rest.isNotEmpty)
          FxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // column captions
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(10.r)),
                  child: Row(
                    children: [
                      SizedBox(width: 38.w, child: Text('#', style: t.overline)),
                      Expanded(
                        child: Text(
                          '${l10n.vehicleCode} · ${l10n.licensePlate}',
                          style: t.overline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text('${l10n.tripsUpper} · KM', style: t.overline),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                for (var i = 0; i < page.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
                  _row(t, l10n, page[i], listStart + offset + i + 1, vehicles.length, maxOrders),
                ],
                FxPager(page: _page, total: rest.length, size: _perPage, onChanged: (p) => setState(() => _page = p)),
              ],
            ),
          ),
      ],
    );
  }

  // ── Podium (ranks 1–3) ────────────────────────────────────────────────────

  Widget _podium(FxTokens t, AppLocalizations l10n, List<ProductionTopVehicle> vehicles) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumTile(t, l10n, vehicles[1], 2, FxTokens.slate, 70.h)),
        SizedBox(width: 8.w),
        Expanded(child: _podiumTile(t, l10n, vehicles[0], 1, FxTokens.amber, 92.h)),
        SizedBox(width: 8.w),
        Expanded(child: _podiumTile(t, l10n, vehicles[2], 3, FxTokens.orange, 58.h)),
      ],
    );
  }

  Widget _podiumTile(FxTokens t, AppLocalizations l10n, ProductionTopVehicle v, int rank, Color medal, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: (rank == 1 ? 38 : 32).w,
          height: (rank == 1 ? 38 : 32).w,
          decoration: BoxDecoration(
            color: t.soft(medal),
            shape: BoxShape.circle,
            border: Border.all(color: medal.withValues(alpha: 0.55), width: 1.5),
          ),
          alignment: Alignment.center,
          child: rank == 1
              ? Icon(Icons.emoji_events_rounded, size: 20.sp, color: t.ink(medal))
              : Text('$rank', style: t.num(13.sp, color: t.ink(medal))),
        ),
        SizedBox(height: 6.h),
        Text(
          v.vehicleName,
          style: t.h3.copyWith(color: t.ink(FxTokens.blue)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.h),
        Text(
          v.vehicleLicensePlate,
          style: t.tiny.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Container(
          height: height,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.soft(FxTokens.blue).withValues(alpha: t.dark ? 0.32 : 0.16), t.soft(FxTokens.blue)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            border: Border(top: BorderSide(color: FxTokens.blue.withValues(alpha: 0.5), width: 2)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${v.totalOrders}', style: t.num(rank == 1 ? 20.sp : 17.sp)),
                  TextSpan(text: ' ${l10n.trips}', style: t.tiny),
                ])),
                SizedBox(height: 2.h),
                Text(
                  '${v.totalDistanceKm.round().toLocaleString()} km',
                  style: t.tiny.copyWith(fontFeatures: FxTokens.tabular, color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Ranking rows ─────────────────────────────────────────────────────────

  Widget _row(FxTokens t, AppLocalizations l10n, ProductionTopVehicle vehicle, int rank, int count, int maxOrders) {
    final tone = _tierTone(rank, count);
    final share = maxOrders > 0 ? vehicle.totalOrders / maxOrders : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 10.h),
      child: Row(
        children: [
          SizedBox(
            width: 38.w,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 28.w,
                height: 28.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone != null ? t.soft(tone) : t.cardAlt,
                  shape: BoxShape.circle,
                  border: tone == null ? Border.all(color: t.border) : null,
                ),
                child: Text(
                  '$rank',
                  style: t.num(11.5.sp, color: tone != null ? t.ink(tone) : t.textMuted),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vehicle.vehicleName,
                        style: t.h3.copyWith(color: tone != null ? t.ink(tone) : t.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: t.cardAlt,
                          border: Border.all(color: t.border),
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          vehicle.vehicleLicensePlate,
                          style: t.tiny.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: t.track,
                    color: tone ?? FxTokens.slate.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 72.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${vehicle.totalOrders}', style: t.num(15.sp)),
                    TextSpan(text: ' ${l10n.trips}', style: t.tiny),
                  ])),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${vehicle.totalDistanceKm.round().toLocaleString()} km',
                  style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on num {
  String toLocaleString() {
    return NumberFormat('#,###').format(this);
  }
}
