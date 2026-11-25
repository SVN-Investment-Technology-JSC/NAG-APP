import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';
import 'package:nguyenanh/features/application_form/presentation/v2/af_ui_v2.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

/// "Tạo đơn xin bận" (v2). Same constructor, state, catalog loading via [ApplicationProvider],
/// validation, payload and returned result (`true`) as `ApplicationFormPage`; grouped card layout.
class ApplicationFormPageV2 extends StatefulWidget {
  const ApplicationFormPageV2({super.key});

  @override
  State<ApplicationFormPageV2> createState() => _ApplicationFormPageV2State();
}

class _ApplicationFormPageV2State extends State<ApplicationFormPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  String? _selectedTagKey;
  int? _selectedVehicleId;
  DateTime _selectedDate = DateTime.now();
  final _reasonController = TextEditingController();
  String _userFullName = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApplicationProvider>(context, listen: false).loadCatalog().then((_) {
        // v2 fix: v1 looked the provider up through `context` before checking `mounted`, which threw
        // when the page was closed while the catalog was still loading.
        if (!mounted) return;
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
    if (!mounted) return; // v2 safety (v1 called setState without the check)
    setState(() {
      _userFullName = prefs.getString('user_full_name') ?? '';
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

  Future<void> _selectDate() async {
    final now = DateTime.now();
    // Same range as v1. (v1 forced a light teal picker theme; v2 uses the app theme so dark mode works.)
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
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
            backgroundColor: FxTokens.emerald,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi đơn thất bại: $e'),
            backgroundColor: FxTokens.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    return Consumer<ApplicationProvider>(
      builder: (context, provider, child) {
        final loading = provider.isCatalogLoading;
        return Scaffold(
          backgroundColor: t.bg,
          appBar: afAppBar(context, title: 'Tạo đơn xin bận', subtitle: 'Gửi đơn để quản lý phê duyệt'),
          bottomNavigationBar: AfBottomBar(
            child: SizedBox(
              height: 48.h,
              child: FilledButton.icon(
                // The form only exists once the catalog has loaded (same as v1, where the button sat inside it).
                onPressed: (_isSubmitting || loading) ? null : _submitForm,
                style: FilledButton.styleFrom(
                  backgroundColor: FxTokens.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: FxTokens.blue.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white,
                ),
                icon: _isSubmitting ? const AfSpinner() : Icon(Icons.send_rounded, size: 18.sp),
                label: Text(_isSubmitting ? 'Đang gửi…' : 'Gửi Đơn Xin Bận'),
              ),
            ),
          ),
          body: loading ? const _FormSkeleton() : _form(t, provider),
        );
      },
    );
  }

  Widget _form(FxTokens t, ApplicationProvider provider) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Requester
            FxCard(
              child: Row(
                children: [
                  AfAvatar(name: _userFullName, tone: FxTokens.blue, size: 42),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userFullName.isEmpty ? '—' : _userFullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.h2,
                        ),
                        SizedBox(height: 2.h),
                        Text('Tài xế vận tải', style: t.small),
                      ],
                    ),
                  ),
                  const FxPill(label: 'Người gửi', tone: FxTokens.slate, icon: Icons.person_outline_rounded),
                ],
              ),
            ),

            // Details
            FxCard(
              padding: EdgeInsets.fromLTRB(14.w, 14.w, 14.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FxSectionHeader(
                    icon: Icons.edit_calendar_rounded,
                    title: 'Chi tiết đơn xin bận',
                    subtitle: 'Chọn lý do, xe và ngày xin bận',
                    tone: FxTokens.blue,
                  ),

                  // Type (tag) — same values as the v1 dropdown, shown as choice pills.
                  AfField(
                    label: 'Lý do bận (Tag)',
                    required: true,
                    child: provider.lotTags.isEmpty
                        ? Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r)),
                            child: Text('Chưa có danh mục lý do bận', style: t.small),
                          )
                        : Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              for (final tag in provider.lotTags)
                                _tagChip(t, tag.lotTagName, tag.lotTagKey == _selectedTagKey, () {
                                  setState(() => _selectedTagKey = tag.lotTagKey);
                                }),
                            ],
                          ),
                  ),

                  // Vehicle
                  AfField(
                    label: 'Chọn xe đăng ký',
                    required: true,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedVehicleId,
                      isExpanded: true,
                      menuMaxHeight: 360.h,
                      style: Theme.of(context).textTheme.bodyMedium!.merge(t.body.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular)),
                      dropdownColor: t.card,
                      borderRadius: BorderRadius.circular(14.r),
                      hint: Text('Chọn xe', style: t.small),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.local_shipping_outlined)),
                      items: provider.vehicles.map((vehicle) {
                        return DropdownMenuItem(
                          value: vehicle.vehicleId,
                          child: Text(_formatVehicleLabel(vehicle), maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedVehicleId = val);
                      },
                    ),
                  ),

                  // Date
                  AfField(
                    label: 'Ngày đăng ký xin bận',
                    required: true,
                    child: Material(
                      color: t.cardAlt,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.border)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _selectDate,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          child: Row(
                            children: [
                              FxIconBadge(icon: Icons.calendar_today_rounded, tone: FxTokens.blue, size: 32),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                                      style: t.num(15.sp),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      MaterialLocalizations.of(context).formatFullDate(_selectedDate),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.tiny,
                                    ),
                                  ],
                                ),
                              ),
                              Text('Đổi', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: t.ink(FxTokens.blue))),
                              SizedBox(width: 2.w),
                              Icon(Icons.chevron_right_rounded, size: 18.sp, color: t.ink(FxTokens.blue)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Reason
                  AfField(
                    label: 'Ghi chú lý do chi tiết',
                    required: true,
                    child: TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: t.body,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        hintText: 'Nhập ý kiến hoặc lý do xin bận cụ thể...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập lý do chi tiết';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const FxBanner(
              tone: FxTokens.blue,
              icon: Icons.info_outline_rounded,
              text: 'Sau khi gửi, đơn ở trạng thái "Chờ duyệt" cho tới khi quản lý phản hồi.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(FxTokens t, String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? t.soft(FxTokens.blue) : t.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: selected ? FxTokens.blue.withValues(alpha: 0.6) : t.border, width: selected ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16.sp,
                color: selected ? t.ink(FxTokens.blue) : t.textFaint,
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? t.ink(FxTokens.blue) : t.text,
                  ),
                ),
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
        FxSkeleton(height: 72.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 420.h, radius: 18),
      ],
    );
  }
}
