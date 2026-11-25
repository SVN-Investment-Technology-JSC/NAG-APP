import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Shared building blocks of the redesigned (v2) "Danh mục" master-data screens: app bar, search field,
/// grouped lazy list, rows, skeleton, add/edit sheet and the red delete confirmation.
///
/// Only presentation lives here — every screen keeps its own state, API calls and permission checks.

// ─── Layout helpers ─────────────────────────────────────────────────────────

/// Horizontal page gutter: 14 on phones, a centred 720-wide column on tablets.
double catalogGutterV2(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 760 ? (width - 720) / 2 : 14.w;
}

/// "12 bộ phận" — or "20+ bộ phận" while more pages can still be loaded.
String catalogCountLabelV2({
  required bool isLoading,
  required int count,
  required bool hasMore,
  required String noun,
}) {
  if (isLoading) return 'Đang tải dữ liệu…';
  return '$count${hasMore && count > 0 ? '+' : ''} $noun';
}

/// App bar of a catalog screen: bold left title + count subtitle on the page background.
PreferredSizeWidget catalogAppBarV2(
  BuildContext context, {
  required String title,
  required String subtitle,
  List<Widget>? actions,
}) {
  final t = FxTokens.of(context);
  return AppBar(
    backgroundColor: t.bg,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 19.sp)),
        SizedBox(height: 1.h),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
        ),
      ],
    ),
    actions: [...?actions, SizedBox(width: 6.w)],
  );
}

class CatalogRefreshButtonV2 extends StatelessWidget {
  final VoidCallback onPressed;

  const CatalogRefreshButtonV2({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return IconButton(
      tooltip: 'Tải lại',
      onPressed: onPressed,
      icon: Icon(Icons.refresh_rounded, size: 22.sp, color: t.textMuted),
    );
  }
}

/// "Thêm mới" floating button (only shown where the role may create).
class CatalogAddFabV2 extends StatelessWidget {
  final VoidCallback onPressed;

  const CatalogAddFabV2({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: FxTokens.blue,
      foregroundColor: Colors.white,
      icon: Icon(Icons.add_rounded, size: 20.sp),
      label: Text('Thêm mới', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Search ─────────────────────────────────────────────────────────────────

/// Search field with a clear button that follows the controller's text.
class CatalogSearchFieldV2 extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const CatalogSearchFieldV2({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide(color: c, width: w));
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: t.body,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: t.small.copyWith(color: t.textFaint),
          prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 18.sp, color: t.textMuted),
                ),
          filled: true,
          fillColor: t.card,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          border: border(t.border),
          enabledBorder: border(t.border),
          focusedBorder: border(FxTokens.blue, 1.4),
        ),
      ),
    );
  }
}

// ─── List ───────────────────────────────────────────────────────────────────

/// Lazy, pull-to-refresh list of rows grouped in one card, with skeleton, empty, error and
/// "loading more" states. [controller] keeps driving the screen's infinite scroll.
class CatalogListV2<T> extends StatelessWidget {
  final ScrollController controller;
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String searchQuery;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? listHint;
  final Widget? header;
  final VoidCallback? onAdd;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double? dividerIndent;

  const CatalogListV2({
    super.key,
    required this.controller,
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.searchQuery,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.onRetry,
    required this.onRefresh,
    required this.itemBuilder,
    this.error,
    this.listHint,
    this.header,
    this.onAdd,
    this.dividerIndent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const CatalogListSkeletonV2();

    final t = FxTokens.of(context);
    final side = catalogGutterV2(context);
    final radius = Radius.circular(FxTokens.rCard);
    final searching = searchQuery.isNotEmpty;

    Widget? placeholder;
    if (items.isEmpty) {
      if (error != null) {
        placeholder = FxEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: 'Kiểm tra kết nối mạng rồi thử lại.',
          action: CatalogErrorActionV2(error: error!, onRetry: onRetry),
        );
      } else if (searching) {
        placeholder = FxEmpty(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy kết quả',
          message: 'Không có mục nào khớp với “$searchQuery”. Hãy thử từ khoá khác.',
        );
      } else {
        placeholder = FxEmpty(
          icon: emptyIcon,
          title: emptyTitle,
          message: onAdd != null ? 'Nhấn “Thêm mới” để tạo mục đầu tiên.' : null,
          action: onAdd == null
              ? null
              : FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm mới'),
                ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (header != null)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 4.h, side, 0),
              sliver: SliverToBoxAdapter(child: header),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side + 4.w, 8.h, side + 4.w, 8.h),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(searching ? 'KẾT QUẢ TÌM KIẾM' : 'DANH SÁCH', style: t.overline),
                  if (searching) ...[
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '“$searchQuery”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.tiny.copyWith(color: t.textFaint),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    if (listHint != null && items.isNotEmpty)
                      Flexible(
                        child: Text(
                          listHint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.tiny.copyWith(color: t.textFaint),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (placeholder != null)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverToBoxAdapter(
                child: FxCard(
                  padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
                  child: Center(child: placeholder),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.all(radius),
                  border: Border.all(color: t.border.withValues(alpha: 0.7)),
                  boxShadow: t.shadow,
                ),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: dividerIndent ?? 66.w,
                    color: t.divider,
                  ),
                  itemBuilder: (context, index) {
                    final child = itemBuilder(context, items[index], index);
                    final first = index == 0, last = index == items.length - 1;
                    if (!first && !last) return child;
                    return ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: first ? radius : Radius.zero,
                        bottom: last ? radius : Radius.zero,
                      ),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(child: _footer(t)),
          SliverToBoxAdapter(child: SizedBox(height: 96.h)),
        ],
      ),
    );
  }

  Widget _footer(FxTokens t) {
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Center(
          child: SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }
    if (items.isNotEmpty && !hasMore) {
      return Padding(
        padding: EdgeInsets.only(top: 14.h),
        child: Center(
          child: Text(
            'Đã hiển thị tất cả ${items.length} mục',
            style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular),
          ),
        ),
      );
    }
    return SizedBox(height: 8.h);
  }
}

/// Technical error detail (trimmed) + "Thử lại" button, shown under an error [FxEmpty].
class CatalogErrorActionV2 extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final String retryLabel;

  const CatalogErrorActionV2({super.key, required this.error, required this.onRetry, this.retryLabel = 'Thử lại'});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.tiny.copyWith(color: t.textFaint),
        ),
        SizedBox(height: 12.h),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(retryLabel),
        ),
      ],
    );
  }
}

/// Placeholder of the list while the first page loads.
class CatalogListSkeletonV2 extends StatelessWidget {
  final int rows;

  const CatalogListSkeletonV2({super.key, this.rows = 7});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final side = catalogGutterV2(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 12.h, side, 24.h),
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
          child: Align(alignment: Alignment.centerLeft, child: FxSkeleton(height: 10.h, width: 90.w, radius: 5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(FxTokens.rCard),
            border: Border.all(color: t.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 66.w, color: t.divider),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
                  child: Row(
                    children: [
                      FxSkeleton(height: 40.w, width: 40.w, radius: 12),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FxSkeleton(height: 12.h, width: (i.isEven ? 150 : 110).w, radius: 6),
                            SizedBox(height: 7.h),
                            FxSkeleton(height: 9.h, width: (i % 3 == 0 ? 210 : 170).w, radius: 5),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Rows ───────────────────────────────────────────────────────────────────

/// One row of a catalog list: leading badge, title, secondary line, meta pills and a "⋮" menu.
class CatalogRowV2 extends StatelessWidget {
  final Widget leading;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final IconData? subtitleIcon;
  final String? placeholder;
  final int subtitleMaxLines;
  final List<Widget> meta;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CatalogRowV2({
    super.key,
    required this.leading,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleIcon,
    this.placeholder,
    this.subtitleMaxLines = 2,
    this.meta = const [],
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final hasMenu = onEdit != null || onDelete != null;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 12.h, hasMenu ? 2.w : 14.w, 12.h),
          child: Row(
            children: [
              leading,
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget ??
                        Text(
                          title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.h3.copyWith(fontSize: 14.sp),
                        ),
                    if (hasSubtitle || placeholder != null) ...[
                      SizedBox(height: 3.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitleIcon != null && hasSubtitle) ...[
                            Padding(
                              padding: EdgeInsets.only(top: 1.h),
                              child: Icon(subtitleIcon, size: 13.sp, color: t.textFaint),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Expanded(
                            child: Text(
                              hasSubtitle ? subtitle! : placeholder!,
                              maxLines: hasSubtitle ? subtitleMaxLines : 1,
                              overflow: TextOverflow.ellipsis,
                              style: hasSubtitle
                                  ? t.small
                                  : t.small.copyWith(color: t.textFaint, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Wrap(spacing: 6.w, runSpacing: 4.h, children: meta),
                    ],
                  ],
                ),
              ),
              if (hasMenu) CatalogRowMenuV2(onEdit: onEdit, onDelete: onDelete) else SizedBox(width: 2.w),
            ],
          ),
        ),
      ),
    );
  }
}

/// "⋮" menu with the row actions the role is allowed to use.
class CatalogRowMenuV2 extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CatalogRowMenuV2({super.key, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    PopupMenuItem<String> item(String value, IconData icon, String label, Color color) => PopupMenuItem<String>(
          value: value,
          height: 44.h,
          child: Row(
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 10.w),
              Text(label, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        );

    return PopupMenuButton<String>(
      tooltip: 'Thao tác',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert_rounded, size: 20.sp, color: t.textMuted),
      onSelected: (v) {
        if (v == 'edit') onEdit?.call();
        if (v == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        if (onEdit != null) item('edit', Icons.edit_outlined, 'Chỉnh sửa', t.text),
        if (onDelete != null) item('delete', Icons.delete_outline_rounded, 'Xóa', t.ink(FxTokens.red)),
      ],
    );
  }
}

/// Round initials avatar with a stable tone per name.
class CatalogAvatarV2 extends StatelessWidget {
  final String name;
  final double size;
  final Color? tone;

  const CatalogAvatarV2({super.key, required this.name, this.size = 40, this.tone});

  static const _palette = [
    FxTokens.blue,
    FxTokens.indigo,
    FxTokens.emerald,
    FxTokens.violet,
    FxTokens.cyan,
    FxTokens.amber,
    FxTokens.orange,
  ];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  static Color toneFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final c = tone ?? toneFor(name);
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft(c), shape: BoxShape.circle),
      child: Text(
        initials(name),
        maxLines: 1,
        style: TextStyle(fontSize: size.w * 0.36, fontWeight: FontWeight.w800, color: t.ink(c), letterSpacing: 0.2),
      ),
    );
  }
}

/// Small square "#3" order badge.
class CatalogIndexBadgeV2 extends StatelessWidget {
  final String label;
  final double size;

  const CatalogIndexBadgeV2({super.key, required this.label, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(size.w * 0.32),
        border: Border.all(color: t.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(label, style: t.num(12.5.sp, color: t.textMuted)),
        ),
      ),
    );
  }
}

// ─── Add / edit sheet ───────────────────────────────────────────────────────

/// Opens a catalog bottom sheet (drag handle, rounded top, keyboard-aware content).
Future<T?> showCatalogSheetV2<T>(BuildContext context, {required WidgetBuilder builder}) {
  final t = FxTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: t.card,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    builder: builder,
  );
}

/// Closes the sheet that owns [sheetContext] — only if it is still the top route
/// (the user may already have dismissed it while a request was running).
void closeCatalogSheetV2(BuildContext sheetContext) {
  if (!sheetContext.mounted) return;
  final route = ModalRoute.of(sheetContext);
  if (route != null && route.isCurrent) Navigator.of(sheetContext).pop();
}

/// Header of a sheet: tinted icon badge + title + subtitle.
class CatalogSheetHeaderV2 extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const CatalogSheetHeaderV2({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 44),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.h2.copyWith(fontSize: 17.sp)),
                SizedBox(height: 2.h),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.small),
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
        ],
      ),
    );
  }
}

/// Sticky action bar at the bottom of a sheet: secondary (outlined) + primary (filled, with loading state).
class CatalogSheetActionsV2 extends StatelessWidget {
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final bool busy;
  final String? busyLabel;
  final Color primaryTone;

  const CatalogSheetActionsV2({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.check_rounded,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.busy = false,
    this.busyLabel,
    this.primaryTone = FxTokens.blue,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final h = 48.h;
    return Container(
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.divider))),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (secondaryLabel != null) ...[
              Expanded(
                child: secondaryIcon == null
                    ? OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(minimumSize: Size(0, h), foregroundColor: t.text),
                        child: Text(secondaryLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      )
                    : OutlinedButton.icon(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(minimumSize: Size(0, h), foregroundColor: t.text),
                        icon: Icon(secondaryIcon, size: 18.sp),
                        label: Text(secondaryLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
              ),
              SizedBox(width: 10.w),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: busy ? null : onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryTone,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryTone.withValues(alpha: 0.55),
                  disabledForegroundColor: Colors.white,
                  minimumSize: Size(0, h),
                ),
                icon: busy
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(primaryIcon, size: 18.sp),
                label: Text(
                  busy ? (busyLabel ?? 'Đang lưu…') : primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit form sheet: header, grouped fields and a sticky action bar whose primary button
/// shows a loading state while [onSubmit] runs (only after [formKey] validates).
class CatalogFormSheetV2 extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String submitLabel;
  final IconData submitIcon;
  final Future<void> Function(BuildContext sheetContext) onSubmit;

  const CatalogFormSheetV2({
    super.key,
    required this.formKey,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.submitIcon = Icons.check_rounded,
  });

  @override
  State<CatalogFormSheetV2> createState() => _CatalogFormSheetV2State();
}

class _CatalogFormSheetV2State extends State<CatalogFormSheetV2> {
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!widget.formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatalogSheetHeaderV2(icon: widget.icon, tone: widget.tone, title: widget.title, subtitle: widget.subtitle),
            Divider(height: 1, thickness: 1, color: t.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 4.h),
                child: Form(
                  key: widget.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                ),
              ),
            ),
            CatalogSheetActionsV2(
              secondaryLabel: 'Hủy',
              onSecondary: _saving ? null : () => Navigator.of(context).pop(),
              primaryLabel: widget.submitLabel,
              primaryIcon: widget.submitIcon,
              onPrimary: _submit,
              busy: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

/// Overline title above a group of fields.
class CatalogFieldGroupV2 extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CatalogFieldGroupV2({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2.w, bottom: 10.h),
          child: Text(title.toUpperCase(), style: t.overline),
        ),
        ...children,
      ],
    );
  }
}

/// Field with its label above (and an optional helper line below).
class CatalogFieldV2 extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? helper;
  final Widget child;

  const CatalogFieldV2({super.key, required this.label, required this.child, this.isRequired = false, this.helper});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label),
                if (isRequired) TextSpan(text: ' *', style: TextStyle(color: t.ink(FxTokens.red))),
              ]),
              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: t.text),
            ),
          ),
          child,
          if (helper != null)
            Padding(
              padding: EdgeInsets.only(left: 2.w, top: 5.h),
              child: Text(helper!, style: t.tiny.copyWith(color: t.textFaint)),
            ),
        ],
      ),
    );
  }
}

/// Input decoration of a catalog field (fill, borders and focus come from the v2 theme).
InputDecoration catalogInputV2(BuildContext context, {String? hint, IconData? icon}) {
  final t = FxTokens.of(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.textFaint),
    prefixIcon: icon == null ? null : Icon(icon, size: 19.sp, color: t.textFaint),
    errorMaxLines: 2,
  );
}

// ─── Delete confirmation ────────────────────────────────────────────────────

/// Red-styled delete confirmation. Resolves to true only when "Xóa" is pressed.
Future<bool> showCatalogDeleteDialogV2(
  BuildContext context, {
  required String message,
  String title = 'Xác nhận xóa',
  String confirmLabel = 'Xóa',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = FxTokens.of(ctx);
      return AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
        titlePadding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 0),
        contentPadding: EdgeInsets.fromLTRB(22.w, 10.h, 22.w, 4.h),
        actionsPadding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 18.h),
        title: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(color: t.soft(FxTokens.red), shape: BoxShape.circle),
              child: Icon(Icons.delete_outline_rounded, size: 26.sp, color: t.ink(FxTokens.red)),
            ),
            SizedBox(height: 12.h),
            Text(title, textAlign: TextAlign.center, style: t.h2.copyWith(fontSize: 17.sp)),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: t.textMuted),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(minimumSize: Size(0, 46.h), foregroundColor: t.text),
                  child: const Text('Hủy'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: FxTokens.red,
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, 46.h),
                  ),
                  icon: Icon(Icons.delete_rounded, size: 18.sp),
                  label: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return ok == true;
}
