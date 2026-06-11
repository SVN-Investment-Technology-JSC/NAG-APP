import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';

class VehicleMaintenanceFormPage extends StatefulWidget {
  final VehicleMaintenance? maintenance;

  const VehicleMaintenanceFormPage({super.key, this.maintenance});

  @override
  State<VehicleMaintenanceFormPage> createState() => _VehicleMaintenanceFormPageState();
}

class _VehicleMaintenanceFormPageState extends State<VehicleMaintenanceFormPage> {
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

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _initData();
  }

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

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.mdH),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 20.sp, color: theme.colorScheme.primary),
          ),
          SizedBox(width: AppSpacing.sm),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.maintenance != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa phiếu bảo trì' : 'Tạo phiếu bảo trì'),
      ),
      body: _vehicles.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(AppSpacing.md),
              children: [
                // === SECTION 1: Thông tin bảo trì ===
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Thông tin bảo trì', Icons.assignment_outlined, theme),
                        DropdownMenu<int>(
                          initialSelection: _selectedVehicleId,
                          expandedInsets: EdgeInsets.zero,
                          enableFilter: true,
                          enableSearch: true,
                          requestFocusOnTap: true,
                          menuHeight: 300.h,
                          leadingIcon: const Icon(Icons.search),
                          hintText: 'Nhập biển số để tìm...',
                          label: const Text('Phương tiện'),
                          onSelected: (val) => setState(() => _selectedVehicleId = val),
                          dropdownMenuEntries: _vehicles.map((v) {
                            return DropdownMenuEntry<int>(
                              value: v.vehicleId,
                              label: '${v.vehicleLicensePlate} - ${v.vehicleName ?? ''}',
                            );
                          }).toList(),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _maintenanceType,
                                decoration: const InputDecoration(labelText: 'Loại phiếu', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'maintenance', child: Text('Bảo dưỡng')),
                                  DropdownMenuItem(value: 'repair', child: Text('Sửa chữa')),
                                  DropdownMenuItem(value: 'inspection', child: Text('Kiểm tra')),
                                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                                ],
                                onChanged: (val) => setState(() => _maintenanceType = val!),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _rank,
                                decoration: const InputDecoration(labelText: 'Mức độ nghiêm trọng', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('Thấp')),
                                  DropdownMenuItem(value: 2, child: Text('Trung bình')),
                                  DropdownMenuItem(value: 3, child: Text('Cao')),
                                ],
                                onChanged: (val) => setState(() => _rank = val!),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _maintenanceStatus,
                                decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'draft', child: Text('Nháp')),
                                  DropdownMenuItem(value: 'submitted', child: Text('Đã gửi')),
                                  DropdownMenuItem(value: 'reviewing', child: Text('Đang duyệt')),
                                  DropdownMenuItem(value: 'approved', child: Text('Đã duyệt')),
                                  DropdownMenuItem(value: 'rejected', child: Text('Từ chối')),
                                  DropdownMenuItem(value: 'completed', child: Text('Hoàn tất')),
                                  DropdownMenuItem(value: 'canceled', child: Text('Đã hủy')),
                                ],
                                onChanged: null,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                controller: _distanceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Số km đã chạy', suffixText: 'km', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Địa điểm sửa chữa', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, _fromDate, (d) => _fromDate = d),
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Từ ngày', border: OutlineInputBorder()),
                                  child: Text(DateFormat('dd/MM/yyyy').format(_fromDate)),
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, _toDate ?? _fromDate, (d) => _toDate = d),
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Đến ngày', border: OutlineInputBorder()),
                                  child: Text(_toDate != null ? DateFormat('dd/MM/yyyy').format(_toDate!) : 'Chưa có'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.mdH),

                // === SECTION 2: Hóa đơn và thanh toán ===
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Hóa đơn và thanh toán', Icons.receipt_long_outlined, theme),
                        TextFormField(
                          controller: _serviceProviderNameController,
                          decoration: const InputDecoration(labelText: 'Đơn vị sửa chữa', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        TextFormField(
                          controller: _serviceProviderAddressController,
                          decoration: const InputDecoration(labelText: 'Địa chỉ đơn vị', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        TextFormField(
                          controller: _invoiceNoController,
                          decoration: const InputDecoration(labelText: 'Số hóa đơn', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        InkWell(
                          onTap: () => _selectDate(context, _invoiceDate, (d) => _invoiceDate = d),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Ngày hóa đơn', border: OutlineInputBorder()),
                            child: Text(_invoiceDate != null ? DateFormat('dd/MM/yyyy').format(_invoiceDate!) : 'Chọn ngày'),
                          ),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _totalAmountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Tổng tiền', border: OutlineInputBorder()),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: const InputDecoration(labelText: 'Tiền tệ', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'VND', child: Text('VND')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                                ],
                                onChanged: (val) => setState(() => _currency = val!),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        DropdownButtonFormField<String>(
                          value: _paymentStatus,
                          decoration: const InputDecoration(labelText: 'Trạng thái thanh toán', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'unpaid', child: Text('Chưa thanh toán')),
                            DropdownMenuItem(value: 'partial', child: Text('Thanh toán 1 phần')),
                            DropdownMenuItem(value: 'paid', child: Text('Đã thanh toán')),
                          ],
                          onChanged: (val) => setState(() => _paymentStatus = val!),
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        InkWell(
                          onTap: () => _selectDate(context, _deadlinePay, (d) => _deadlinePay = d),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Hạn thanh toán', border: OutlineInputBorder()),
                            child: Text(_deadlinePay != null ? DateFormat('dd/MM/yyyy').format(_deadlinePay!) : 'Chọn hạn'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.mdH),

                // === SECTION 3: Chi tiết công việc ===
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Chi tiết công việc', Icons.handyman_outlined, theme),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Mô tả công việc', border: OutlineInputBorder(), alignLabelWithHint: true),
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.mdH),

                // === SECTION 4: Tài liệu và OCR ===
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Tài liệu và OCR', Icons.camera_alt_outlined, theme),
                        TextFormField(
                          controller: _ocrController,
                          decoration: const InputDecoration(
                            labelText: 'Nội dung OCR / bản dịch hóa đơn',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                        ),
                        SizedBox(height: AppSpacing.mdH),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.smH,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Chọn ảnh/PDF'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tính năng chọn ảnh từ thư viện đang cập nhật')),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                icon: _isOcrLoading 
                                  ? SizedBox(width: 16.sp, height: 16.sp, child: const CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.document_scanner_outlined),
                                label: Text(_isOcrLoading ? 'Đang đọc...' : 'Đọc OCR (Camera)'),
                                onPressed: _isOcrLoading ? null : _pickImageForOcr,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32.h),

                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Lưu phiếu bảo trì'),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
    );
  }
}
