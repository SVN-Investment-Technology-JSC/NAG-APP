import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/application_form/data/models/application_model.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';
import 'package:nguyenanh/features/application_form/presentation/screens/application_form_page.dart';
import 'package:nguyenanh/features/application_form/presentation/screens/application_detail_page.dart';

class ApplicationListPage extends StatefulWidget {
  const ApplicationListPage({super.key});

  @override
  State<ApplicationListPage> createState() => _ApplicationListPageState();
}

class _ApplicationListPageState extends State<ApplicationListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _userRole = '';
  String _userFullName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'driver';
      _userFullName = prefs.getString('user_full_name') ?? '';
    });
    await _loadData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    final mine = _userRole == 'driver';
    final status = _getStatusFromIndex(_tabController.index);
    await Provider.of<ApplicationProvider>(context, listen: false).fetchRequests(
      page: 1,
      limit: 100,
      status: status,
      mine: mine,
    );
  }

  String _getStatusFromIndex(int index) {
    switch (index) {
      case 0:
        return 'pending';
      case 1:
        return 'approved';
      case 2:
        return 'rejected';
      case 3:
        return 'canceled';
      default:
        return 'pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981); // Emerald
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'canceled':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  String _getVietnameseStatus(String status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'canceled':
        return 'Đã hủy';
      default:
        return 'Chờ duyệt';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDriver = _userRole == 'driver';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Đơn xin bận',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0D9488),
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: const Color(0xFF0D9488),
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
              tabs: const [
                Tab(text: 'Chờ duyệt'),
                Tab(text: 'Đã duyệt'),
                Tab(text: 'Từ chối'),
                Tab(text: 'Đã hủy'),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<ApplicationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF0D9488),
            child: _buildListSection(provider.requests, theme, colorScheme),
          );
        },
      ),
      floatingActionButton: isDriver
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApplicationFormPage()),
                );
                if (result == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tạo đơn'),
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildListSection(List<LotTagRequest> items, ThemeData theme, ColorScheme colorScheme) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180.h),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 64.sp, color: const Color(0xFF94A3B8)),
                SizedBox(height: 16.h),
                Text(
                  'Không có đơn từ nào trong danh sách',
                  style: TextStyle(color: const Color(0xFF64748B), fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final statusColor = _getStatusColor(item.requestStatus);
        final dateStr = _formatDate(item.workDate);

        final vehiclePlate = item.vehicle?.vehicleLicensePlate;
        final vehicleName = item.vehicle?.vehicleName;
        final vehicleLabel = [vehiclePlate, vehicleName].where((e) => e != null && e.isNotEmpty).join(' · ');

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ApplicationDetailPage(applicationId: item.lotTagRequestId),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        (item.lotTag?.lotTagName ?? item.lotTagKey).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _getVietnameseStatus(item.requestStatus),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  item.requestedByUser?.userFullName ?? 'Tài xế #${item.requestedBy ?? ''}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (vehicleLabel.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 14.sp, color: const Color(0xFF94A3B8)),
                      SizedBox(width: 6.w),
                      Text(
                        vehicleLabel,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14.sp, color: const Color(0xFF94A3B8)),
                    SizedBox(width: 6.w),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (item.requestReason != null && item.requestReason!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    item.requestReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
