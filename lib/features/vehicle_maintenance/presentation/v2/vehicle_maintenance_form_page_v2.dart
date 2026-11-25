import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vm_ui_v2.dart';

/// Create / edit a maintenance ticket (v2). Same constructor, fields, controllers, OCR flow, payload,
/// API calls and returned result (`true` after a successful save) as `VehicleMaintenanceFormPage`.
class VehicleMaintenanceFormPageV2 extends StatefulWidget {
  final VehicleMaintenance? maintenance;

  const VehicleMaintenanceFormPageV2({super.key, this.maintenance});

  @override
  State<VehicleMaintenanceFormPageV2> createState() => _VehicleMaintenanceFormPageV2State();
}

class _VehicleMaintenanceFormPageV2State extends State<VehicleMaintenanceFormPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _service = VehicleMaintenanceService(ApiClient.dio);
  final _vehicleService = VehicleService(ApiClient.dio);
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isOcrLoading = false;
  List<VehicleModel> _vehicles = [];

  // Section 1: Thông tin bảo trì
  int? _selectedVehicleId;
  String _maintenanceType = 'maintenance';
  int _rank = 1;
  String _maintenanceStatus = 'draft';
  final _distanceController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _fromDate = DateTime.now();
  DateTime? _toDate;

  // Section 2: Hóa đơn và thanh toán
  final _serviceProviderNameController = TextEditingController();
  final _serviceProviderAddressController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  DateTime? _invoiceDate;
  final _totalAmountController = TextEditingController();
  String _currency = 'VND';
  String _paymentStatus = 'unpaid';
  DateTime? _deadlinePay;

  // Section 3: Chi tiết công việc
  final _descController = TextEditingController();

  // Section 4: Tài liệu và OCR
  final _ocrController = TextEditingController();

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// v1 showed a spinner forever when the vehicle list came back empty; v2 shows a retry state instead.
  bool _vehiclesFetched = false;

  @override
  void initState() {
    super.initState();
    _loadVehiclesV2();
    _initData();
  }

  void _loadVehiclesV2() {
    _loadVehicles().whenComplete(() {
      if (mounted) setState(() => _vehiclesFetched = true);
    });
  }

  @override
  void dispose() {
    // v2: the v1 page never disposed its controllers.
    _distanceController.dispose();
    _locationController.dispose();
    _serviceProviderNameController.dispose();
    _serviceProviderAddressController.dispose();
    _invoiceNoController.dispose();
    _totalAmountController.dispose();
    _descController.dispose();
    _ocrController.dispose();
    super.dispose();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

  void _initData() {
    if (widget.maintenance != null) {
      final m = widget.maintenance!;
      _selectedVehicleId = m.vehicleId;
      _maintenanceType = m.vehicleMaintenanceType ?? 'maintenance';
      _rank = m.vehicleMaintenanceRank ?? 1;
      _maintenanceStatus = m.vehicleMaintenanceStatus ?? 'draft';
      _distanceController.text = m.vehicleDistanceCovered?.toStringAsFixed(0) ?? '';
      _locationController.text = m.vehicleMaintenanceLocation ?? '';
      _fromDate = m.vehicleMaintenanceFromDatetime;
      _toDate = m.vehicleMaintenanceToDatetime;

      _serviceProviderNameController.text = m.serviceProviderName ?? '';
      _serviceProviderAddressController.text = m.serviceProviderAddress ?? '';
      _invoiceNoController.text = m.invoiceNo ?? '';
      _invoiceDate = m.invoiceDate;
      _totalAmountController.text = m.totalAmount?.toStringAsFixed(0) ?? '';
      _currency = m.currency ?? 'VND';
      _paymentStatus = m.paymentStatus ?? 'unpaid';
      _deadlinePay = m.deadlinePay;

      _descController.text = m.vehicleMaintenanceDescription ?? '';
      _ocrController.text = m.vehicleMaintenanceOcrText ?? '';
    }
  }

  Future<void> _loadVehicles() async {
    final vehicles = await _vehicleService.getVehicles();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        if (_selectedVehicleId == null && _vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first.vehicleId;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onPicked) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        onPicked(picked);
      });
    }
  }

  Future<void> _pickImageForOcr() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;

    setState(() => _isOcrLoading = true);

    try {
      final text = await _service.extractOcr(image.path);
      if (mounted) {
        if (text != null && text.isNotEmpty) {
          _ocrController.text = text;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OCR thành công')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không quét được văn bản')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi OCR: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn xe')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'vehicle_id': _selectedVehicleId,
        'vehicle_maintenance_type': _maintenanceType,
        'vehicle_maintenance_rank': _rank,
        'vehicle_maintenance_status': _maintenanceStatus,
        'vehicle_distance_covered': double.tryParse(_distanceController.text),
        'vehicle_maintenance_location': _locationController.text,
        'vehicle_maintenance_from_datetime': _fromDate.toIso8601String(),
        'vehicle_maintenance_to_datetime': _toDate?.toIso8601String(),

        'service_provider_name': _serviceProviderNameController.text,
        'service_provider_address': _serviceProviderAddressController.text,
        'invoice_no': _invoiceNoController.text,
        'invoice_date': _invoiceDate?.toIso8601String(),
        'total_amount': double.tryParse(_totalAmountController.text),
        'currency': _currency,
        'payment_status': _paymentStatus,
        'deadline_pay': _deadlinePay?.toIso8601String(),

        'vehicle_maintenance_description': _descController.text,
        'vehicle_maintenance_ocr_text': _ocrController.text,
      };

      if (widget.maintenance == null) {
        await _service.create(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thành công')));
          Navigator.pop(context, true);
        }
      } else {
        await _service.update(widget.maintenance!.vehicleMaintenanceId, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Option lists (same values / labels as the v1 dropdowns) ───────────────

  static const _statusLabels = {
    'draft': 'Nháp',
    'submitted': 'Đã gửi',
    'reviewing': 'Đang duyệt',
    'approved': 'Đã duyệt',
    'rejected': 'Từ chối',
    'completed': 'Hoàn tất',
    'canceled': 'Đã hủy',
  };

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final isEditing = widget.maintenance != null;
    final ready = _vehicles.isNotEmpty;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: vmAppBar(
        context,
        title: isEditing ? 'Sửa phiếu bảo trì' : 'Tạo phiếu bảo trì',
        subtitle: isEditing ? 'Phiếu #${widget.maintenance!.vehicleMaintenanceId}' : 'Điền thông tin phiếu bảo trì',
      ),
      bottomNavigationBar: ready
          ? VmBottomBar(
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: FxTokens.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: FxTokens.blue.withValues(alpha: 0.55),
                    disabledForegroundColor: Colors.white,
                  ),
                  icon: _isLoading ? const VmButtonSpinner() : Icon(Icons.save_rounded, size: 19.sp),
                  label: Text(_isLoading ? 'Đang lưu…' : 'Lưu phiếu bảo trì'),
                ),
              ),
            )
          : null,
      body: !ready
          ? (_vehiclesFetched
              ? Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: FxEmpty(
                      icon: Icons.local_shipping_outlined,
                      title: 'Không tải được danh sách xe',
                      message: 'Cần danh sách phương tiện để lập phiếu bảo trì.',
                      action: FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => _vehiclesFetched = false);
                          _loadVehiclesV2();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  ),
                )
              : const _FormSkeleton())
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                children: [
                  _infoSection(t),
                  _invoiceSection(t),
                  _workSection(t),
                  _ocrSection(t),
                ],
              ),
            ),
    );
  }

  /// Dropdown text style: merged onto the theme body style so the app font family is kept.
  TextStyle _dropdownStyle(FxTokens t) =>
      Theme.of(context).textTheme.bodyMedium!.merge(t.body.copyWith(fontWeight: FontWeight.w600));

  // === SECTION 1: Thông tin bảo trì ===
  Widget _infoSection(FxTokens t) {
    final df = DateFormat('dd/MM/yyyy');
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.assignment_outlined,
            title: 'Thông tin bảo trì',
            subtitle: 'Phương tiện, loại phiếu và thời gian',
            tone: FxTokens.blue,
            trailing: FxPill(
              label: _statusLabels[_maintenanceStatus] ?? _maintenanceStatus,
              tone: VmTone.status(_maintenanceStatus),
              dot: true,
            ),
          ),
          VmField(
            label: 'Phương tiện',
            required: true,
            child: DropdownMenu<int>(
              initialSelection: _selectedVehicleId,
              expandedInsets: EdgeInsets.zero,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              menuHeight: 300.h,
              leadingIcon: const Icon(Icons.search),
              hintText: 'Nhập biển số để tìm...',
              textStyle: t.body.copyWith(fontWeight: FontWeight.w600),
              onSelected: (val) => setState(() => _selectedVehicleId = val),
              dropdownMenuEntries: _vehicles.map((v) {
                return DropdownMenuEntry<int>(
                  value: v.vehicleId,
                  label: '${v.vehicleLicensePlate} - ${v.vehicleName}',
                );
              }).toList(),
            ),
          ),
          VmField(
            label: 'Loại phiếu',
            child: FxSegmented<String>(
              dense: true,
              segments: const [
                FxSegment('maintenance', 'Bảo dưỡng'),
                FxSegment('repair', 'Sửa chữa'),
                FxSegment('inspection', 'Kiểm tra'),
                FxSegment('other', 'Khác'),
              ],
              value: _maintenanceType,
              onChanged: (val) => setState(() => _maintenanceType = val),
            ),
          ),
          VmField(
            label: 'Mức độ nghiêm trọng',
            child: FxSegmented<int>(
              dense: true,
              segments: [
                const FxSegment(1, 'Thấp'),
                const FxSegment(2, 'Trung bình'),
                const FxSegment(3, 'Cao'),
                // v2 fix: rank 4 (from the web app) crashed the v1 dropdown; keep it selectable when present.
                if (widget.maintenance?.vehicleMaintenanceRank == 4) const FxSegment(4, 'Khẩn cấp'),
              ],
              value: _rank,
              onChanged: (val) => setState(() => _rank = val),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VmField(
                  label: 'Số km đã chạy',
                  child: TextFormField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    style: t.body.copyWith(fontFeatures: FxTokens.tabular),
                    decoration: const InputDecoration(hintText: '0', suffixText: 'km', prefixIcon: Icon(Icons.speed_rounded)),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: VmField(
                  label: 'Địa điểm sửa chữa',
                  child: TextFormField(
                    controller: _locationController,
                    style: t.body,
                    decoration: const InputDecoration(hintText: 'Nơi sửa chữa', prefixIcon: Icon(Icons.place_outlined)),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: VmField(
                  label: 'Từ ngày',
                  child: VmPickerField(
                    icon: Icons.event_rounded,
                    text: df.format(_fromDate),
                    onTap: () => _selectDate(context, _fromDate, (d) => _fromDate = d),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: VmField(
                  label: 'Đến ngày',
                  child: VmPickerField(
                    icon: Icons.event_available_rounded,
                    text: _toDate != null ? df.format(_toDate!) : 'Chưa có',
                    placeholder: _toDate == null,
                    onTap: () => _selectDate(context, _toDate ?? _fromDate, (d) => _toDate = d),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === SECTION 2: Hóa đơn và thanh toán ===
  Widget _invoiceSection(FxTokens t) {
    final df = DateFormat('dd/MM/yyyy');
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Hóa đơn và thanh toán',
            subtitle: 'Đơn vị sửa chữa, hóa đơn, chi phí',
            tone: FxTokens.emerald,
          ),
          VmField(
            label: 'Đơn vị sửa chữa',
            child: TextFormField(
              controller: _serviceProviderNameController,
              style: t.body,
              decoration: const InputDecoration(hintText: 'Tên đơn vị', prefixIcon: Icon(Icons.storefront_outlined)),
            ),
          ),
          VmField(
            label: 'Địa chỉ đơn vị',
            child: TextFormField(
              controller: _serviceProviderAddressController,
              style: t.body,
              decoration: const InputDecoration(hintText: 'Địa chỉ', prefixIcon: Icon(Icons.map_outlined)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: VmField(
                  label: 'Số hóa đơn',
                  child: TextFormField(
                    controller: _invoiceNoController,
                    style: t.body.copyWith(fontFeatures: FxTokens.tabular),
                    decoration: const InputDecoration(hintText: 'Số HĐ', prefixIcon: Icon(Icons.tag_rounded)),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: VmField(
                  label: 'Ngày hóa đơn',
                  child: VmPickerField(
                    icon: Icons.event_note_rounded,
                    text: _invoiceDate != null ? df.format(_invoiceDate!) : 'Chọn ngày',
                    placeholder: _invoiceDate == null,
                    onTap: () => _selectDate(context, _invoiceDate, (d) => _invoiceDate = d),
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: VmField(
                  label: 'Tổng tiền',
                  child: TextFormField(
                    controller: _totalAmountController,
                    keyboardType: TextInputType.number,
                    style: t.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular),
                    decoration: const InputDecoration(hintText: '0', prefixIcon: Icon(Icons.payments_outlined)),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 1,
                child: VmField(
                  label: 'Tiền tệ',
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    style: _dropdownStyle(t),
                    dropdownColor: t.card,
                    borderRadius: BorderRadius.circular(14.r),
                    items: [
                      const DropdownMenuItem(value: 'VND', child: Text('VND')),
                      const DropdownMenuItem(value: 'USD', child: Text('USD')),
                      // v2 fix: a stored currency outside the list crashed the v1 dropdown (value assertion).
                      if (_currency != 'VND' && _currency != 'USD') DropdownMenuItem(value: _currency, child: Text(_currency)),
                    ],
                    onChanged: (val) => setState(() => _currency = val!),
                  ),
                ),
              ),
            ],
          ),
          VmField(
            label: 'Trạng thái thanh toán',
            child: DropdownButtonFormField<String>(
              initialValue: _paymentStatus,
              isExpanded: true,
              style: _dropdownStyle(t),
              dropdownColor: t.card,
              borderRadius: BorderRadius.circular(14.r),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: t.ink(VmTone.payment(_paymentStatus))),
              ),
              items: [
                const DropdownMenuItem(value: 'unpaid', child: Text('Chưa thanh toán')),
                const DropdownMenuItem(value: 'partial', child: Text('Thanh toán 1 phần')),
                const DropdownMenuItem(value: 'paid', child: Text('Đã thanh toán')),
                // v2 fix: an unknown stored value crashed the v1 dropdown (value assertion).
                if (!const ['unpaid', 'partial', 'paid'].contains(_paymentStatus))
                  DropdownMenuItem(value: _paymentStatus, child: Text(_paymentStatus)),
              ],
              onChanged: (val) => setState(() => _paymentStatus = val!),
            ),
          ),
          VmField(
            label: 'Hạn thanh toán',
            child: VmPickerField(
              icon: Icons.alarm_rounded,
              text: _deadlinePay != null ? df.format(_deadlinePay!) : 'Chọn hạn',
              placeholder: _deadlinePay == null,
              onTap: () => _selectDate(context, _deadlinePay, (d) => _deadlinePay = d),
            ),
          ),
        ],
      ),
    );
  }

  // === SECTION 3: Chi tiết công việc ===
  Widget _workSection(FxTokens t) {
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(
            icon: Icons.handyman_outlined,
            title: 'Chi tiết công việc',
            subtitle: 'Hạng mục bảo trì, sửa chữa',
            tone: FxTokens.amber,
          ),
          VmField(
            label: 'Mô tả công việc',
            child: TextFormField(
              controller: _descController,
              style: t.body,
              decoration: const InputDecoration(hintText: 'Mô tả các hạng mục đã / sẽ thực hiện…', alignLabelWithHint: true),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  // === SECTION 4: Tài liệu và OCR ===
  Widget _ocrSection(FxTokens t) {
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(
            icon: Icons.document_scanner_outlined,
            title: 'Tài liệu và OCR',
            subtitle: 'Quét hóa đơn để lấy nội dung tự động',
            tone: FxTokens.violet,
          ),
          VmField(
            label: 'Nội dung OCR / bản dịch hóa đơn',
            child: TextFormField(
              controller: _ocrController,
              style: t.body,
              decoration: const InputDecoration(hintText: 'Nội dung được quét sẽ hiển thị tại đây', alignLabelWithHint: true),
              maxLines: 5,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _toolButton(
                  t,
                  icon: Icons.cloud_upload_outlined,
                  label: 'Chọn ảnh/PDF',
                  tone: FxTokens.blue,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng chọn ảnh từ thư viện đang cập nhật')),
                    );
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _toolButton(
                  t,
                  icon: Icons.document_scanner_outlined,
                  label: _isOcrLoading ? 'Đang đọc...' : 'Đọc OCR (Camera)',
                  tone: FxTokens.violet,
                  loading: _isOcrLoading,
                  onTap: _isOcrLoading ? null : _pickImageForOcr,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
    FxTokens t, {
    required IconData icon,
    required String label,
    required Color tone,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return Material(
      color: t.soft(tone),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          child: Column(
            children: [
              if (loading)
                SizedBox(
                  width: 20.sp,
                  height: 20.sp,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.ink(tone)),
                )
              else
                Icon(icon, size: 20.sp, color: t.ink(tone)),
              SizedBox(height: 6.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: t.ink(tone)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FxSkeleton(height: 380.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 300.h, radius: 18),
      ],
    );
  }
}
