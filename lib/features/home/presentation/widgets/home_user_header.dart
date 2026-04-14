import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:vehicle_management/core/theme/app_colors.dart';
import 'package:vehicle_management/core/theme/app_spacing.dart';

class HomeUserHeader extends StatelessWidget {
  final String userFullName;
  final String userRole;
  final int orderCount;
  final bool isSocketConnected;
  final bool isLedConnected;

  const HomeUserHeader({
    super.key,
    required this.userFullName,
    required this.userRole,
    required this.orderCount,
    required this.isSocketConnected,
    required this.isLedConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smH),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          _UserRow(
            userFullName: userFullName,
            userRole: userRole,
            orderCount: orderCount,
          ),
          SizedBox(height: AppSpacing.smH),
          Row(
            children: [
              _StatusChip(label: 'Cap nhat', isConnected: isSocketConnected),
              SizedBox(width: AppSpacing.sm),
              _StatusChip(label: 'Bang led', isConnected: isLedConnected),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String userFullName;
  final String userRole;
  final int orderCount;

  const _UserRow({
    required this.userFullName,
    required this.userRole,
    required this.orderCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 20.r,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.person_rounded,
              color: colorScheme.onPrimaryContainer, size: 24.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userFullName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                userRole.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            '$orderCount',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isConnected;

  const _StatusChip({
    required this.label,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExtension>()!;
    final color = isConnected ? ext.success : theme.colorScheme.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
