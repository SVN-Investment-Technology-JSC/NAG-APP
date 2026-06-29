import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/screens/vehicle_maintenance_form_page.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/screens/vehicle_maintenance_detail_page.dart';

class VehicleMaintenanceListPage extends StatefulWidget {
  const VehicleMaintenanceListPage({super.key});

  @override
  State<VehicleMaintenanceListPage> createState() => _VehicleMaintenanceListPageState();
}

class _VehicleMaintenanceListPageState extends State<VehicleMaintenanceListPage> {
  final VehicleMaintenanceService _service = VehicleMaintenanceService(ApiClient.dio);
  
  List<VehicleMaintenance> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _searchQuery;
  String _sortBy = '-created_at';
  String _currentTab = 'all';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<Map<String, String>> _tabs = [
    {'value': 'all', 'label': 'Tất cả'},
    {'value': 'mine', 'label': 'Của tôi'},
    {'value': 'submitted', 'label': 'Chờ kiểm tra'},
    {'value': 'reviewing', 'label': 'Chờ phê duyệt'},
    {'value': 'approved', 'label': 'Đã duyệt'},
    {'value': 'rejected', 'label': 'Từ chối'},
  ];
  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canCreate = false;
  bool _canUpdate = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__delete');
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? status;
      bool mine = false;
      if (_currentTab == 'mine') {
        mine = true;
      } else if (_currentTab != 'all') {
        status = _currentTab;
      }

      final items = await _service.getVehicleMaintenances(
        limit: 50,
        search: _searchQuery,
        sort: _sortBy,
        status: status,
        mine: mine,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
    if (status == 'completed' || status == 'approved') return Colors.green;
    if (status == 'rejected' || status == 'canceled') return Colors.red;
    if (status == 'reviewing') return Colors.blue;
    return Colors.orange; // draft, submitted
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'submitted': return 'Đã gửi';
      case 'reviewing': return 'Đang duyệt';
      case 'approved': return 'Đã duyệt';
      case 'rejected': return 'Từ chối';
      case 'completed': return 'Hoàn tất';
      case 'canceled': return 'Đã hủy';
      default: return status ?? 'Nháp';
    }
  }

  Future<void> _deleteMaintenance(int id) async {
    try {
      final success = await _service.delete(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa phiếu bảo trì')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xóa thất bại: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(VehicleMaintenance item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phiếu bảo trì?'),
        content: const Text('Phiếu bảo trì và tài liệu liên quan sẽ được xóa mềm. Bạn có chắc chắn muốn xóa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMaintenance(item.vehicleMaintenanceId);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _getRankLabel(int? rank) {
    switch (rank) {
      case 1: return 'Thấp';
      case 2: return 'Trung bình';
      case 3: return 'Cao';
      case 4: return 'Khẩn cấp';
      default: return 'Không xác định';
    }
  }

  Color _getRankColor(int? rank) {
    switch (rank) {
      case 1: return Colors.grey;
      case 2: return Colors.blue;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  String _getPaymentStatusLabel(String? status) {
    switch (status) {
      case 'unpaid': return 'Chưa thanh toán';
      case 'partial': return 'Thanh toán 1 phần';
      case 'paid': return 'Đã thanh toán';
      default: return 'Chưa thanh toán';
    }
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = _currentTab == tab['value'];
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FilterChip(
              label: Text(tab['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _currentTab = tab['value']!);
                  _loadData();
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm phương tiện...',
                  hintStyle: TextStyle(fontSize: 14.sp),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        ) 
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
                ),
                onChanged: (val) {
                  setState(() {});
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() => _searchQuery = val);
                    _loadData();
                  });
                },
                onSubmitted: (val) {
                  setState(() => _searchQuery = val);
                  _loadData();
                },
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            height: 40.h,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: 'Sắp xếp',
              onSelected: (val) {
                setState(() => _sortBy = val);
                _loadData();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: '-created_at', child: Text('Mới nhất')),
                PopupMenuItem(value: 'created_at', child: Text('Cũ nhất')),
                PopupMenuItem(value: '-vehicle_maintenance_from_datetime', child: Text('Ngày bảo trì (Mới -> Cũ)')),
                PopupMenuItem(value: 'vehicle_maintenance_from_datetime', child: Text('Ngày bảo trì (Cũ -> Mới)')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bảo trì & Bảo dưỡng xe'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          if (_canCreate)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehicleMaintenanceFormPage()),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          _buildTabs(),
          _buildSearchAndFilter(),
          if (_isLoading && _items.isNotEmpty)
            const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(theme, colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error),
            SizedBox(height: 16.h),
            Text('Lỗi tải dữ liệu: $_error'),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text('Không có dữ liệu', style: theme.textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.smH),
      itemBuilder: (context, index) {
        final item = _items[index];
        final vehicleLabel = item.vehicle?.vehicleLicensePlate ?? '#${item.vehicleId}';
        final formatter = DateFormat('dd/MM/yyyy HH:mm');
        final fromDate = formatter.format(item.vehicleMaintenanceFromDatetime);
        final statusColor = _getStatusColor(item.vehicleMaintenanceStatus);

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Slidable(
            key: ValueKey(item.vehicleMaintenanceId),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.65,
              children: [
                SlidableAction(
                  onPressed: (_) async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VehicleMaintenanceDetailPage(maintenanceId: item.vehicleMaintenanceId)),
                    );
                    if (result == true) {
                      _loadData();
                    }
                  },
                  backgroundColor: colorScheme.primaryContainer.withOpacity(0.7),
                  foregroundColor: colorScheme.primary,
                  icon: Icons.info_outline,
                  label: 'Chi tiết',
                ),
                if (_canUpdate)
                  SlidableAction(
                    onPressed: (_) async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VehicleMaintenanceFormPage(maintenance: item)),
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    backgroundColor: Colors.orange.shade100.withOpacity(0.7),
                    foregroundColor: Colors.orange.shade800,
                    icon: Icons.edit_outlined,
                    label: 'Sửa',
                  ),
                if (_canDelete)
                  SlidableAction(
                    onPressed: (_) {
                      _showDeleteConfirmDialog(item);
                    },
                    backgroundColor: Colors.red.shade100.withOpacity(0.7),
                    foregroundColor: Colors.red.shade800,
                    icon: Icons.delete_outline,
                    label: 'Xóa',
                  ),
              ],
            ),
            child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VehicleMaintenanceDetailPage(maintenanceId: item.vehicleMaintenanceId)),
              );
              if (result == true) {
                _loadData();
              }
            },
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car_rounded, size: 20.sp, color: colorScheme.primary),
                          SizedBox(width: 8.w),
                          Text(
                            vehicleLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          _getStatusLabel(item.vehicleMaintenanceStatus),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16.sp, color: colorScheme.outline),
                      SizedBox(width: 8.w),
                      Text(
                        fromDate,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.vehicleMaintenanceDescription?.isNotEmpty == true) ...[
                    SizedBox(height: 8.h),
                    Text(
                      item.vehicleMaintenanceDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: _getRankColor(item.vehicleMaintenanceRank).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          _getRankLabel(item.vehicleMaintenanceRank),
                          style: TextStyle(fontSize: 10.sp, color: _getRankColor(item.vehicleMaintenanceRank), fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          _getPaymentStatusLabel(item.paymentStatus),
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (item.documents != null && item.documents!.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Row(
                          children: [
                            Icon(Icons.attach_file, size: 14.sp, color: Colors.grey[600]),
                            SizedBox(width: 2.w),
                            Text('${item.documents!.length}', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ), // closes InkWell
          ), // closes Card
        ); // closes Slidable
      },
    );
  }
}
