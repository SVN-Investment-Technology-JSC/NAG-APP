import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/app_colors.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class HomeShiftBanner extends StatefulWidget {
  final int pendingCount;
  final int collectingCount;
  final VoidCallback onShiftClosed;

  const HomeShiftBanner({
    super.key,
    required this.pendingCount,
    required this.collectingCount,
    required this.onShiftClosed,
  });

  @override
  State<HomeShiftBanner> createState() => _HomeShiftBannerState();
}

class _HomeShiftBannerState extends State<HomeShiftBanner> {
  bool _isLoading = false;

  bool get _canClose => widget.pendingCount == 0 && widget.collectingCount == 0;

  Future<void> _handleShiftClose() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shiftCloseConfirmTitle),
        content: Text(l10n.shiftCloseConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final service = OrderService(ApiClient.dio);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await service.shiftClose(today);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shiftCloseSuccess)),
      );
      widget.onShiftClosed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shiftCloseFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    final hasBlockers = widget.pendingCount > 0 || widget.collectingCount > 0;
    final bannerColor = hasBlockers ? ext.warning : ext.success;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xsH),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.h),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: bannerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shiftClose,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: bannerColor,
                  ),
                ),
                if (hasBlockers) ...[
                  SizedBox(height: AppSpacing.xsH),
                  Text(
                    l10n.shiftPendingWarning(
                        widget.pendingCount + widget.collectingCount),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: bannerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _canClose && !_isLoading ? _handleShiftClose : null,
            style: FilledButton.styleFrom(
              backgroundColor: bannerColor,
              disabledBackgroundColor: colorScheme.outline.withValues(alpha: 0.12),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smH),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    l10n.shiftClose,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _canClose
                          ? colorScheme.onPrimary
                          : colorScheme.outline,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
