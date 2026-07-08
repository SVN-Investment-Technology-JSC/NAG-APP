import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class ApplicationFormPage extends StatefulWidget {
  const ApplicationFormPage({super.key});

  @override
  State<ApplicationFormPage> createState() => _ApplicationFormPageState();
}

class _ApplicationFormPageState extends State<ApplicationFormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTagKey;
  int? _selectedVehicleId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  final _reasonController = TextEditingController();
  String _userFullName = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApplicationProvider>(context, listen: false).loadCatalog().then((_) {
        final provider = Provider.of<ApplicationProvider>(context, listen: false);
        if (provider.lotTags.isNotEmpty && mounted) {
          setState(() {
            _selectedTagKey = provider.lotTags.first.lotTagKey;
          });
        }
        if (provider.vehicles.isNotEmpty && mounted) {
          setState(() {
            _selectedVehicleId = provider.vehicles.first.vehicleId;
          });
        }
      });
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userFullName = prefs.getString('user_full_name') ?? '';
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatVehicleLabel(WorkVehicle vehicle) {
    final plate = vehicle.vehicleLicensePlate;
    final name = vehicle.vehicleName;
    final label = [plate, name].where((e) => e != null && e.isNotEmpty).join(' · ');
    return label.isNotEmpty ? label : '#${vehicle.vehicleId}';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTagKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn loại đơn từ')),
      );
      return;
    }
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn xe')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ApplicationProvider>();
      final selectedTag = provider.lotTags.firstWhere((tag) => tag.lotTagKey == _selectedTagKey);

      await provider.createRequest(
        workDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        vehicleId: _selectedVehicleId!,
        lotTagId: selectedTag.lotTagId,
        lotTagKey: selectedTag.lotTagKey,
        requestReason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gửi đơn thành công, đang chờ phê duyệt.'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi đơn thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Tạo đơn xin bận',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<ApplicationProvider>(
        builder: (context, provider, child) {
          if (provider.isCatalogLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver info banner
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20.r,
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: Icon(Icons.person, color: const Color(0xFF94A3B8), size: 24.sp),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userFullName,
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Tài xế vận tải',
                              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Application Form details
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết đơn xin bận',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                        ),
                        SizedBox(height: 16.h),

                        // Type Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedTagKey,
                          decoration: InputDecoration(
                            labelText: 'Lý do bận (Tag)',
                            labelStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            isDense: true,
                          ),
                          items: provider.lotTags.map((tag) {
                            return DropdownMenuItem(
                              value: tag.lotTagKey,
                              child: Text(tag.lotTagName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTagKey = val);
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Vehicle Dropdown
                        DropdownButtonFormField<int>(
                          value: _selectedVehicleId,
                          decoration: InputDecoration(
                            labelText: 'Chọn xe đăng ký',
                            labelStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            isDense: true,
                          ),
                          items: provider.vehicles.map((vehicle) {
                            return DropdownMenuItem(
                              value: vehicle.vehicleId,
                              child: Text(_formatVehicleLabel(vehicle)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedVehicleId = val);
                          },
                        ),
                        SizedBox(height: 16.h),

                        // Date picker row
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ngày đăng ký xin bận',
                                  style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 14.sp, color: const Color(0xFF0D9488)),
                                    SizedBox(width: 6.w),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Reason Text Field
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Ghi chú lý do chi tiết',
                            labelStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                            alignLabelWithHint: true,
                            hintText: 'Nhập ý kiến hoặc lý do xin bận cụ thể...',
                            hintStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập lý do chi tiết';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Gửi Đơn Xin Bận',
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
